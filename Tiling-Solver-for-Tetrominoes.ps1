#Tiling_Solver_for_Tetrominoes
#
#Ver 0.6

using namespace System.Collections.Generic


#==================================================
#From EFL (Ver 0.05 Alpha)
#Poll されたデータを解凍
function TSolver_EFL_Base64ToValue([String]$Str, [Int]$StartIndex, [Int]$Length)
{
    $output_value = 0

    for($i = 0; $i -lt $Length; $i++)
    {
        $output_value += [Math]::pow(64, $i) * 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.IndexOf($Str.Substring($StartIndex + $i, 1))
    }
    return $output_value
}


#データを Poll
function TSolver_EFL_ValueToBase64([Int]$Value, [Int]$Length)
{
    $output_str = ''
    for($i = 0; $i -lt $Length; $i++)
    {
        
        $output_str += 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.Substring($Value % 64, 1)

        $Value -= $Value % 64
        $Value /= 64

    }
    return $output_str
}


#各ピースの形状の一覧を取得する
function TSolver_EFL_GetPieceShapeTable
{
    $piece_shape_table = @(
        #1 I
        (-01, +00, +01, +02),
        (-10, +00, +10, +20),
        (-01, +00, +01, +02),
        (-10, +00, +10, +20),

        #2 L
        (-01, +00, +01, +09),
        (-10, +00, +10, +11),
        (-09, -01, +00, +01),
        (-11, -10, +00, +10),

        #3 O
        (+00, +01, +10, +11),
        (+00, +01, +10, +11),
        (+00, +01, +10, +11),
        (+00, +01, +10, +11),

        #4 Z
        (-01, +00, +10, +11),
        (-09, +00, +01, +10),
        (-01, +00, +10, +11),
        (-09, +00, +01, +10),

        #5 T
        (-01, +00, +01, +10),
        (-10, +00, +01, +10),
        (-10, -01, +00, +01),
        (-10, -01, +00, +10),

        #6 J
        (-01, +00, +01, +11),
        (-10, -09, +00, +10),
        (-11, -01, +00, +01),
        (-10, +00, +09, +10),

        #7 S
        (+00, +01, +09, +10),
        (-11, -01, +00, +10),
        (+00, +01, +09, +10),
        (-11, -01, +00, +10)
    )
    return ,$piece_shape_table
}


#テーブル形式に展開したフィールド情報をもとに、ミノを設置する
function TSolver_EFL_EditTable_LockPiece([List[int]]$FieldData, [int]$Piece, [int]$Rotation, [int]$Location)
{
    if($Piece -ne 0)
    {
        #各ピースの形状に関する情報を取得
        $piece_shape_table = TSolver_EFL_GetPieceShapeTable
        
        for($i = 0; $i -lt 4; $i++)
        {
            
            $FieldData[$Location + $piece_shape_table[($Piece - 1) * 4 + $Rotation][$i]] = $Piece
        }

    }
    return ,$FieldData
}


#テーブル形式に展開したフィールド情報をもとに、埋まっている段を消去する
function TSolver_EFL_EditTable_ClearFilledLine([List[int]]$FieldData)
{
    for($i = 220; $i -ge 0; $i -= 10)
    {
        if($FieldData.IndexOf(0, $i, 10) -eq -1) #0 が無ければその段を消す
        {
            $FieldData.RemoveRange($i, 10)
        }
    }
    #消した分を足す
    $FieldData.InsertRange(0, [int[]]@(0) * (240 - $FieldData.count))
    return ,$FieldData
}


#テーブル形式に展開したフィールド情報をもとに、せり上げる
function TSolver_EFL_EditTable_Raise([List[int]]$FieldData)
{
    $FieldData.RemoveRange(0, 10)
    $FieldData.AddRange([int[]]@(0) * 10)
    return ,$FieldData
}


#テーブル形式に展開したフィールド情報をもとに、左右を反転させる
function TSolver_EFL_EditTable_Mirror([List[int]]$FieldData)
{
    for($i = 0; $i -le 220; $i += 10) #お邪魔の段は反転しない
    {
        $FieldData.Reverse($i, 10)
    }
    return ,$FieldData
}


#フィールドの更新
function TSolver_EFL_EditTable_UpdateField([List[int]]$FieldData, [int]$Piece, [int]$Rotation, [int]$Location, [int]$Flag_Lock, [int]$Flag_Raise, [int]$Flag_Mirror)
{
    if($Flag_Lock -eq 1)
    {
        #置く (未対応)
        $FieldData = TSolver_EFL_EditTable_LockPiece $FieldData $Piece $Rotation $Location

        #消す
        $FieldData = TSolver_EFL_EditTable_ClearFilledLine $FieldData
    
        #せり上げる
        if($Flag_Raise -eq 1)
        {
            $FieldData = TSolver_EFL_EditTable_Raise $FieldData
        }

        #反転
        if($Flag_Mirror -eq 1)
        {
            $FieldData = TSolver_EFL_EditTable_Mirror $FieldData
        }
    }

    return ,$FieldData
}


#URL 形式のデータをテーブルに展開する
function TSolver_EFL_EditFumen_RawToTable([String]$Tetfu)
{
    #コメントの詳細な編集には未対応
    #Quiz 機能には非対応
    #
    #
    #1 ページ目用初期設定

    $Tetfu = $Tetfu -replace '\?', ''
    $ptr = $Tetfu.IndexOf('@') + 1

    $field_prev = [List[int]](@(0) * 240)
    $comment_prev_length = 0
    $comment_prev = ''
    $vh_counter = 0

    #全体のテーブル
    $data_list_table = New-Object List[Object]


    #ここからループ対象
    Do
    {
        $field_diff = New-Object List[int](240)
        $field_current = New-Object List[int](240)

        #フィールドの差分を出力
        if($vh_counter -eq 0)　#vh 省略区間外
        {
            do
            {
                $field_value = TSolver_EFL_Base64ToValue $Tetfu $ptr 2

                $cell_count = $field_value % 240
                $cell_diff = ($field_value - $cell_count) / 240

                $field_diff.AddRange([int[]]@($cell_diff) * ($cell_count + 1)) 
                $ptr += 2

            } while($field_diff.count -lt 240)

            #vh 先頭処理
            if($field_value -eq 2159)
            {
                $vh_counter = TSolver_EFL_Base64ToValue $Tetfu $ptr 1
                $ptr += 1
            }
        }
        else #vh 省略区間内
        {
            $field_diff = [List[int]](@(8) * 240)
            $vh_counter--
        }


        #現在のフィールドを計算
        for($i = 0; $i -le 239; $i++)
        {
            $field_current.Add($field_diff[$i] + $field_prev[$i] - 8)
        }


        #ミノ、フラグの解凍

        $flags_value = TSolver_EFL_Base64ToValue $Tetfu $ptr 3
        $ptr += 3

        #操作中のミノの種類
        $piece = $flags_value % 8
        $flags_value = [Math]::Floor($flags_value / 8)

        #操作中のミノの向き
        $rotation = $flags_value % 4
        $flags_value = [Math]::Floor($flags_value / 4)

        #操作中のミノの場所
        $location = $flags_value % 240
        $flags_value = [Math]::Floor($flags_value / 240)

        #ミノ非選択時
        if($piece -eq 0)
        {
            $rotation = 0
            $location = 0
        }

        #せりあがりフラグ
        $flag_raise = $flags_value % 2
        $flags_value = [Math]::Floor($flags_value / 2)

        #鏡フラグ
        $flag_mirror = $flags_value % 2
        $flags_value = [Math]::Floor($flags_value / 2)

        #色フラグ
        if($data_list_table.Count -eq 0)
        {
            $flag_color = $flags_value % 2
        }
        $flags_value = [Math]::Floor($flags_value / 2)

        #コメントフラグ
        $flag_comment = $flags_value % 2
        $flags_value = [Math]::Floor($flags_value / 2)

        #接着フラグ
        $flag_lock = ($flags_value + 1) % 2


        #コメントの文字数
        switch($flag_comment)
        {
            1
            {
                $comment_current_length = TSolver_EFL_Base64ToValue $Tetfu $ptr 2
                $ptr += 2
                }
            0
            {
                $comment_current_length = $comment_prev_length
            }
        }

        #コメント文字列解凍
        switch($flag_comment)
        {
            1
            {
                #仮コード (未サポート機能)
                $comment_current = $Tetfu.Substring($ptr, (5 * [Math]::Ceiling($comment_current_length / 4)))
                #コメントの分ポインタを動かす
                $ptr += (5 * [Math]::Ceiling($comment_current_length / 4))
            }
            0
            {
                $comment_current = $comment_prev
            }
        }


        #後処理

        #フィールドの更新
        $field_prev = New-Object List[int]([List[int[]]]$field_current)
        $field_prev = TSolver_EFL_EditTable_UpdateField $field_prev $piece $rotation $location $flag_lock $flag_raise $flag_mirror



        #Quiz の更新
        #$comment_prev_length
        #$comment_prev
        #
        #仮コード (未サポート機能)
        $comment_prev_length = $comment_current_length
        $comment_prev = $comment_current
        #仮コードここまで

        $data_list_table.Add([object]@{field_current = $field_current; field_updated = $field_prev; piece = $piece; rotation = $rotation; location = $location; flag_raise = $flag_raise; flag_mirror = $flag_mirror; flag_color = $flag_color; flag_comment = $flag_comment; flag_lock = $flag_lock; comment_current_length = $comment_current_length; comment_current = $comment_current; comment_updated_length = $comment_prev_length; comment_updated = $comment_prev;})


    } while($ptr -lt $Tetfu.Length)
    #echo $data_list_table.GetType()
    

    return ,$data_list_table
}


#テーブル形式のデータをエンコードする
function TSolver_EFL_EditFumen_TableToRaw([List[object]]$Data_List_Table)
{
    #コメントの詳細な編集には未対応
    #
    #1 ページ目用初期設定

    $field_prev = [List[int]](@(0) * 240)
    $comment_prev_length = 0
    $comment_prev = ''
    $vh_counter = -1

    #全体のテーブル
    $encoder_table = New-Object List[System.Text.StringBuilder]

    #ここからループ対象

    for($page = 0; $page -lt $Data_List_Table.Count; $page++)
    {
        #echo $page.GetType()
        
        $field_diff = New-Object List[int](240)
        
        $field_current = New-Object List[int]([List[int[]]]($Data_List_Table[$page].field_current))

        $field_value_list = New-Object List[int]
        $cell_diff_prev = -1

        #フィールドの差分を計算
        for($i = 0; $i -le 239; $i++)
        {
            $field_diff.Add($field_current[$i] - $field_prev[$i] + 8)
    
            $cell_diff_current = $field_diff[$i]
            if($cell_diff_current -eq $cell_diff_prev)
            {
                $field_value_list[$field_value_list.Count - 1] ++
            }
            else
            {
                $field_value_list.Add($cell_diff_current * 240)
                $cell_diff_prev = $cell_diff_current
            }
        }


        $piece = $Data_List_Table[$page].piece
        $rotation = $Data_List_Table[$page].rotation
        $location = $Data_List_Table[$page].location
        $flag_raise = $Data_List_Table[$page].flag_raise
        $flag_mirror = $Data_List_Table[$page].flag_mirror

        #color
        if($page -eq 0)
        {
            $flag_color = $Data_List_Table[$page].flag_color
        }
        else
        {
            $flag_color = 0
        }

        #lock
        $flag_lock = $Data_List_Table[$page].flag_lock

        #comment
        if($comment_prev.Equals($Data_List_Table[$page].comment_current))
        {
            $flag_comment = 0
            $comment_current_length = 0
            $comment_current = ''
        }
        else
        {
            $flag_comment = 1
            $comment_current_length = $Data_List_Table[$page].comment_current_length
            $comment_current = $Data_List_Table[$page].comment_current
        }

        #Encode
        $building_str = New-Object System.Text.StringBuilder
        $is_vh = (($field_value_list | ForEach-Object {TSolver_EFL_ValueToBase64 $PSItem 2}) -join '') -eq 'vh'

        #フィールド部分
        #vh 区間の起点の場合
        if(($vh_counter -eq -1) -and $is_vh)
        {
            $vh_start = $page
            $vh_counter++
        }
        #vh 区間内 (終点含む) の場合
        elseif(($vh_counter -ge 0) -and $is_vh)
        {
            $vh_counter++
        }
        #非 vh 区間の起点の場合
        elseif(($vh_counter -ge 0) -and (-not $is_vh))
        {
            #vh 開始地点に vh の情報を挿入する
            $encoder_table[$vh_start].Insert(0, 'vh' + (TSolver_EFL_ValueToBase64 $vh_counter 1)) | Out-Null
            #vh カウンターをリセットする
            $vh_counter = -1
            #現ページのフィールド
            $building_str.Append(($field_value_list | ForEach-Object {TSolver_EFL_ValueToBase64 $PSItem 2}) -join '') | Out-Null
        }
        #非 vh 区間内 (終点含む) の場合
        else
        {
            #現ページのフィールド
            $building_str.Append(($field_value_list | ForEach-Object {TSolver_EFL_ValueToBase64 $PSItem 2}) -join '') | Out-Null
        }

        #vh/ 特別処理
        if($vh_counter -eq 63)
        {
            #vh 開始地点に vh の情報を挿入する
            $encoder_table[$vh_start].Insert(0, 'vh/') | Out-Null
            #vh カウンターをリセットする
            $vh_counter = -1
        }
        #最終ページ例外処理
        #処理が二重にならないように elseif
        elseif(($page -eq ($Data_List_Table.Count - 1)) -and $is_vh -and ($vh_counter -ne 0))
        {
            #vh 開始地点に vh の情報を挿入する
            $encoder_table[$vh_start].Insert(0, 'vh' + (TSolver_EFL_ValueToBase64 $vh_counter 1)) | Out-Null
            #vh カウンターを念のためリセットする
            $vh_counter = -1
        }
        #最後 1 ページしかない場合はエラー回避が必要
        elseif(($page -eq ($Data_List_Table.Count - 1)) -and $is_vh -and ($vh_counter -eq 0))
        {
            #vh 開始地点に vh の情報を挿入する
            $building_str.Append('vhA') | Out-Null
            #vh カウンターを念のためリセットする
            $vh_counter = -1
        }

        #ミノ・フラグ
        $building_str.Append((TSolver_EFL_ValueToBase64 ($piece + $rotation * 8 + $location * 32 + $flag_raise * 7680 + $flag_mirror * 15360 + $flag_color * 30720 + $flag_comment * 61440 + (($flag_lock + 1) % 2) * 122880) 3)) | Out-Null
        #コメント
        if($flag_comment -eq 1)
        {
            $building_str.Append((TSolver_EFL_ValueToBase64 $comment_current_length 2)) | Out-Null
            $building_str.Append($comment_current) | Out-Null
        }
        $encoder_table.Add($building_str)

        
        #後処理
        $field_prev = New-Object List[int]([List[int[]]]($Data_List_Table[$page].field_updated))
        $comment_prev_length = $Data_List_Table[$page].comment_updated_length
        $comment_prev = $Data_List_Table[$page].comment_updated
    }

    $encoder_table = $encoder_table | ForEach-Object {$PSItem.ToString()}

    $raw_str = 'v115@'
    $raw_str += $encoder_table -join ''
    

    for($i = 0; (48 * $i + 47) -le ($raw_str.Length); $i++)
    {
        $raw_str = $raw_str.Insert(48 * $i + 47,'?')
    }
    
    return $raw_str
}


#空のテト譜 Raw データを取得
function TSolver_EFL_Blank-Fumen
{
    return 'v115@vhAAgH'
}


#Raw データからページ数を求める
function TSolver_EFL_Count([String]$Tetfu_Raw)
{
    $tetfu_table = TSolver_EFL_EditFumen_RawToTable $Tetfu_Raw
    return $tetfu_table.Count
}


#テト譜を指定したページ数ずつに分割する
function TSolver_EFL_Chunk([String]$Tetfu_Raw, [int]$Size = 1)
{
    $tetfu_table = TSolver_EFL_EditFumen_RawToTable $Tetfu_Raw

    for($i = 0; $i -lt [math]::Ceiling($tetfu_table.Count / $Size); $i++) 
    {
        TSolver_EFL_EditFumen_TableToRaw $tetfu_table[(($Size * $i)..($Size * ($i + 1) - 1))]
    }
    return
}


#指定したページの地形の高さを取得する (リストで指定可能)
function TSolver_EFL_Get-Height([String]$Tetfu_Raw, [List[int]]$PageNo = [List[int]]::new([int[]](1..(TSolver_EFL_Count $Tetfu_Raw))))
{
    $tetfu_table = TSolver_EFL_EditFumen_RawToTable $Tetfu_Raw

    for($i = 0; $i -lt $PageNo.Count; $i++) 
    {
        (23 - [math]::Floor($tetfu_table[$PageNo[$i] - 1].field_current.FindIndex({$args -ne 0}) / 10)) % 24
    }

   return
}
    
#EFL ここまで
#
#以降 T-Solver オリジナル部分

#==================================================
#クラス定義

class TSolver_FumensList: List[String]
{
    #----------------------------------------
    #Raw データ
    [List[string]]Raw() { return $this }
    
    #----------------------------------------
    #連続テト譜エディタ (EDIT)
    [List[string]]URL()
    {
        return $(
            if($this[0] -eq 'Not Found')
            { $this } 
            else
            { switch($this) { default {'https://fumen.zui.jp/?' + $_} } }
        )
    }

    [List[string]]Edit()
    {
        return $(
            if($this[0] -eq 'Not Found')
            { $this } 
            else
            { switch($this) { default {'https://fumen.zui.jp/?' + $_} } }
        )
    }

    #----------------------------------------
    #連続テト譜エディタ (LIST_Full)
    [List[string]]ListFull()
    {
        return $(
            if($this[0] -eq 'Not Found')
            { $this }
            else
            { switch($this) { default {'https://fumen.zui.jp/?d' + $_.SubString(1)} } }
        )
    }

    [List[string]]List()
    {
        return $(
            if($this[0] -eq 'Not Found')
            { $this }
            else
            { switch($this) { default {'https://fumen.zui.jp/?d' + $_.SubString(1)} } }
        )
    }

    #----------------------------------------
    #連続テト譜エディタ (LIST_Min)
    [List[string]]ListMin()
    {
        return $(
            if($this[0] -eq 'Not Found')
            { $this }
            else
            { switch($this) { default {'https://fumen.zui.jp/?D' + $_.SubString(1)} } }
        )
    }

    #----------------------------------------
    #連続テト譜エディタ (VIEW)
    [List[string]]View()
    {
        return $(
            if($this[0] -eq 'Not Found')
            { $this }
            else
            { switch($this) { default {'https://fumen.zui.jp/?m' + $_.SubString(1)} } }
        )
    }

    #----------------------------------------
    #Fumen for mobile
    [List[string]]Mobile()
    {
        return $(
            if($this[0] -eq 'Not Found')
            { $this }
            else
            { switch($this) { default {'https://knewjade.github.io/fumen-for-mobile/#?d=' + $_} } }
        )
    }

    #----------------------------------------
    #Hard Drop (Edit)
    [List[string]]HardDrop()
    {
        return $(
            if($this[0] -eq 'Not Found')
            { $this }
            else
            { switch($this) { default {'https://harddrop.com/fumen/?' + $_} } }
        )
    }
    
    #----------------------------------------
    #Hard Drop (LIST)
    [List[string]]HardDropList()
    {
        return $(
            if($this[0] -eq 'Not Found')
            { $this }
            else
            { switch($this) { default {'https://harddrop.com/fumen/?d' + $_.SubString(1)} } }
        )
    }

    #----------------------------------------
    #Hard Drop (VIEW)
    [List[string]]HardDropView()
    {
        return $(
            if($this[0] -eq 'Not Found')
            { $this }
            else
            { switch($this) { default {'https://harddrop.com/fumen/?m' + $_.SubString(1)} } }
        )
    }

}

class TSolver_FumensList_All: TSolver_FumensList
{
    #Chunk
    [TSolver_FumensList]Chunk([int]$TSolver_chunk_size)
    {
        if($this[0] -eq 'Not Found')
        { return $this }
        else
        {
            $all_solutions_tetfu_chunk = [TSolver_FumensList]::new()
            $all_solutions_tetfu_chunk.AddRange([List[String]](TSolver_EFL_Chunk $this[0] $TSolver_chunk_size))
            return $all_solutions_tetfu_chunk
        }
    }
}


#==================================================
#T-Solver 本体

function Find-Tilings([String]$Input_Tetfu, [Int]$Page_No = 1, [List[int]]$Pieces_Counter_Input = (0,0,0,0,0,0,0))
{
    #後でちゃんと実装する
    #_ILOZTJSX
    [List[int]]$pieces_counter = $Pieces_Counter_Input[0,2,3,6,5,1,4]

    #変数

    #検索に使用するためのミノの情報をテーブルで取得する
    $finder_piece_info_table = (
        #01:I(ns)
        @{finder_piece_id = 01; piece_no = 1; rotation_no = 2; shape = (-01, +00, +01, +02); x_bigin = 1; x_end = 7; y_bigin = 0; y_end = -1},
        #02:I(ew) 
        @{finder_piece_id = 02; piece_no = 1; rotation_no = 1; shape = (-10, +00, +10, +20); x_bigin = 0; x_end = 9; y_bigin = 2; y_end = -2},
        #03:J(n)
        @{finder_piece_id = 03; piece_no = 6; rotation_no = 2; shape = (-11, -01, +00, +01); x_bigin = 1; x_end = 8; y_bigin = 0; y_end = -2},
        #04:J(e)
        @{finder_piece_id = 04; piece_no = 6; rotation_no = 1; shape = (-10, -09, +00, +10); x_bigin = 0; x_end = 8; y_bigin = 1; y_end = -2},
        #05:J(s)
        @{finder_piece_id = 05; piece_no = 6; rotation_no = 0; shape = (-01, +00, +01, +11); x_bigin = 1; x_end = 8; y_bigin = 1; y_end = -1},
        #06:J(w)
        @{finder_piece_id = 06; piece_no = 6; rotation_no = 3; shape = (-10, +00, +09, +10); x_bigin = 1; x_end = 9; y_bigin = 1; y_end = -2},
        #07:L(n)
        @{finder_piece_id = 07; piece_no = 2; rotation_no = 2; shape = (-09, -01, +00, +01); x_bigin = 1; x_end = 8; y_bigin = 0; y_end = -2},
        #08:L(e)
        @{finder_piece_id = 08; piece_no = 2; rotation_no = 1; shape = (-10, +00, +10, +11); x_bigin = 0; x_end = 8; y_bigin = 1; y_end = -2},
        #09:L(s)
        @{finder_piece_id = 09; piece_no = 2; rotation_no = 0; shape = (-01, +00, +01, +09); x_bigin = 1; x_end = 8; y_bigin = 1; y_end = -1},
        #10:L(w)
        @{finder_piece_id = 10; piece_no = 2; rotation_no = 3; shape = (-11, -10, +00, +10); x_bigin = 1; x_end = 9; y_bigin = 1; y_end = -2},
        #11:O(nesw)
        @{finder_piece_id = 11; piece_no = 3; rotation_no = 2; shape = (+00, +01, +10, +11); x_bigin = 0; x_end = 8; y_bigin = 1; y_end = -1},
        #12:S(ns)
        @{finder_piece_id = 12; piece_no = 7; rotation_no = 2; shape = (+00, +01, +09, +10); x_bigin = 1; x_end = 8; y_bigin = 1; y_end = -1},
        #13:S(ew)
        @{finder_piece_id = 13; piece_no = 7; rotation_no = 1; shape = (-11, -01, +00, +10); x_bigin = 1; x_end = 9; y_bigin = 1; y_end = -2},
        #14:Z(ns)
        @{finder_piece_id = 14; piece_no = 4; rotation_no = 2; shape = (-01, +00, +10, +11); x_bigin = 1; x_end = 8; y_bigin = 1; y_end = -1},
        #15:Z(ew)
        @{finder_piece_id = 15; piece_no = 4; rotation_no = 1; shape = (-09, +00, +01, +10); x_bigin = 0; x_end = 8; y_bigin = 1; y_end = -2},
        #16:T(n)
        @{finder_piece_id = 16; piece_no = 5; rotation_no = 2; shape = (-10, -01, +00, +01); x_bigin = 1; x_end = 8; y_bigin = 0; y_end = -2},
        #17:T(e)
        @{finder_piece_id = 17; piece_no = 5; rotation_no = 1; shape = (-10, +00, +01, +10); x_bigin = 0; x_end = 8; y_bigin = 1; y_end = -2},
        #18:T(s)
        @{finder_piece_id = 18; piece_no = 5; rotation_no = 0; shape = (-01, +00, +01, +10); x_bigin = 1; x_end = 8; y_bigin = 1; y_end = -1},
        #19:T(w)
        @{finder_piece_id = 19; piece_no = 5; rotation_no = 3; shape = (-10, -01, +00, +10); x_bigin = 1; x_end = 9; y_bigin = 1; y_end = -2}
    )

    #関数

    #次の 1 手の置き方を列挙する
    function Get_Placement_List($Field_To_Fill_Hashset)
    {
        $placement_list = New-Object List[Object]
    
        foreach($piece in $finder_piece_info_table)
        {
            #指定にないミノは探索しない
            if($pieces_counter[$piece.piece_no - 1])
            {
                foreach($y in ($piece.y_bigin)..($height + $piece.y_end))
                {
                    foreach($x in ($piece.x_bigin)..($piece.x_end))
                    {
                        $location = ($x + 10 * (23 - $y - 1))

                        #配置できるか判定
                        $can_place = $field_to_fill_hashset.IsSupersetOf([List[int]](($location + $piece.shape[0]), ($location + $piece.shape[1]), ($location + $piece.shape[2]), ($location + $piece.shape[3])))

                        if($can_place)
                        {
                            #リストに置き方を追加
                            $placement_list.Add([object]@{piece_id = $piece.finder_piece_id; piece_no = $piece.piece_no; rotation_no = $piece.rotation_no; location = $location; filled_cells = [HashSet[int]](($location + $piece.shape[0]), ($location + $piece.shape[1]), ($location + $piece.shape[2]), ($location + $piece.shape[3]));})
                        }
                    }
                }
            }
        }

        return ,$placement_list
    }

    #セルごとに置き方が何通りあるかの一覧を返す
    #埋まっているセルは 100
    function Count_Placements_By_Cell([List[Object]]$Placement_List, $Field_To_Fill_Hashset)
    { 
        $placement_count_by_cell = [int[]]::new(230)

        switch ($Placement_List.filled_cells)
        {
            default
            {
                $placement_count_by_cell[$_]++
            }
        }
        return $placement_count_by_cell
    }

    function place_piece
    {

        #--------------------
        #ミノを置く

        #n ミノ目の情報は $current_placement の (n - 1) の位置に入る
        #最新のものは -1 で呼び出せる
        $current_placement.Add($_)

        #既に置いた位置に被らないように
        $field_to_fill_hashset.ExceptWith($current_placement[-1].filled_cells)
        
        #上記で置いたので、ミノ数のカウンターを更新する
        $pieces_counter[$current_placement[-1].piece_no - 1]--
        #--------------------
        
        #--------------------
        #全セルが埋まっていればそれが解なので、記録して戻る
        if($field_to_fill_hashset.Count -eq 0)
        {
            $current_solution = New-Object List[Object]([List[Object[]]]($current_placement))
            $solutions_table.Add($current_solution)
            $pieces_counter[$current_placement[-1].piece_no - 1]++
            $field_to_fill_hashset.UnionWith($current_placement[-1].filled_cells)
            $current_placement.RemoveAt($current_placement.Count - 1)
            return
        }

        #--------------------

        #--------------------
        #次に試す置き方のリストを生成する
        #
        #置くことが出来る 1 手のリストを生成する
        #前の階層で使ったものからフィルターして求める
        $placement_list = $placement_list.FindAll([Predicate[object]]{ param($x) $x.filled_cells.IsSubsetOf($field_to_fill_hashset) -and $pieces_counter[$x.piece_no - 1] })
        
        #(この間でパリティや盤面の分割を考慮してさらに絞り込むこともやろうと思えばできる)


        if($placement_list.Count -eq 0)
        {
            #置き方がないので戻る
            $pieces_counter[$current_placement[-1].piece_no - 1]++
            $field_to_fill_hashset.UnionWith($current_placement[-1].filled_cells)
            $current_placement.RemoveAt($current_placement.Count - 1)
            return
        }
        
        #セルごとに置き方が何通りあるかの一覧を返す
        [List[Int]]$placement_count_by_cell = Count_Placements_By_Cell $placement_list $field_to_fill_hashset

        #置き方が最も少ないセルの置き方が何通りあるか取得する
        #同時に、置き方が最も少ないセルの位置を取得する
        $min = 100
        switch($field_to_fill_hashset)
        {
            default
            {
                if($placement_count_by_cell[$_] -lt $min)
                {
                    $min = $placement_count_by_cell[$_]
                    $tgt_index = $_
                }
            }
        }
        
        if($min -eq 0)
        {
            #埋められないマスがあるので戻る
            $pieces_counter[$current_placement[-1].piece_no - 1]++
            $field_to_fill_hashset.UnionWith($current_placement[-1].filled_cells)
            $current_placement.RemoveAt($current_placement.Count - 1)
            return
        }

        #---------------------
        #$placement_buff[1] なら、1 ミノ置いた状態を記憶している

        $placement_buff.Add([List[Object]]::new())
        $placement_buff[-1].AddRange($placement_list)

        #---------------------
        #各要素についてループする

        switch($placement_buff[-1])
        {
            default
            {
                #置き方が最も少ないセルに置く方法を試す
                if( ($_.filled_cells).Contains($tgt_index) )
                {                
                    $placement_list.Clear()
                    $placement_list.AddRange($placement_buff[-1])

                    place_piece
                }
            }
        }

        #全部を確かめたので戻る
        $placement_buff.RemoveAt($placement_buff.Count - 1)
        $pieces_counter[$current_placement[-1].piece_no - 1]++
        $field_to_fill_hashset.UnionWith($current_placement[-1].filled_cells)

        $current_placement.RemoveAt($current_placement.Count - 1)

        Return
        #--------------------

    }

    #--------------------
    #--------------------
    #開始時処理

    $solutions_table = New-Object List[List[Object]]

    $height = TSolver_EFL_Get-Height $Input_Tetfu $Page_No

    #アウトプット用意
    $num_of_solutions = 0
    $solutions_tetfu_splited = [TSolver_FumensList]::new()
    $solutions_tetfu_reduced = [TSolver_FumensList]::new()
    $solutions_tetfu_all = [TSolver_FumensList_All]::new()

    #高さが 0 だった場合、解なしとして終了する
    if($height -eq 0)
    {
        $solutions_tetfu_splited.Add('Not Found')
        $solutions_tetfu_reduced.Add('Not Found')
        $solutions_tetfu_all.Add('Not Found')
    
        return @{num = $num_of_solutions; all = $solutions_tetfu_all ; split = $solutions_tetfu_splited; reduce = $solutions_tetfu_reduced}
    }


    $field_base = (TSolver_EFL_EditFumen_RawToTable $Input_Tetfu)[$Page_No - 1].field_current

    $field_to_fill_hashset = New-Object HashSet[int](230)

    switch(0..229)
    {
        default
        {
            #色を指定した処理に後程対応
            if(($field_base[$_]) -ne 0)
            {
                $field_base[$_] = 0
                [void]$field_to_fill_hashset.Add($_)
            }
        }
    }
    
    #ブロック数を数える
    $num_of_blocks = $field_to_fill_hashset.Count

    #ブロック数が 4 の倍数でないならば解なしとして終了する
    if($num_of_blocks % 4)
    {
        $solutions_tetfu_splited.Add('Not Found')
        $solutions_tetfu_reduced.Add('Not Found')
        $solutions_tetfu_all.Add('Not Found')
    
        return @{num = $num_of_solutions; all = $solutions_tetfu_all ; split = $solutions_tetfu_splited; reduce = $solutions_tetfu_reduced}
    }

    #必要なミノ数を判定
    $need_pieces = [math]::Floor($num_of_blocks / 4)

    #入力されたミノ数を数える
    $pieces_counter_sum = 0
    switch ($pieces_counter) { default{$pieces_counter_sum += $_} }

    #ミノが足りなければ、解なしとして終了する
    if($pieces_counter_sum -lt $need_pieces)
    {
        $solutions_tetfu_splited.Add('Not Found')
        $solutions_tetfu_reduced.Add('Not Found')
        $solutions_tetfu_all.Add('Not Found')
    
        return @{num = $num_of_solutions; all = $solutions_tetfu_all ; split = $solutions_tetfu_splited; reduce = $solutions_tetfu_reduced}
    }

    #指定にあるミノに限り 1 つの置き方を列挙する
    $placement_list = Get_Placement_List $field_to_fill_hashset

    #--------------------
    #パリティ関連処理
    #Rule:201 と Rule:211 について知りたいので、Rule:200 を調べる

    [List[int]]$parity_r200 = @(0,0,0,0)
    switch($field_to_fill_hashset)
    {
        default
        {
            $parity_r200[$_ % 2 + [math]::Floor($_ / 10) % 2 * 2]++
        }
    }

    $parity_r211_diff = $parity_r200[0] + $parity_r200[3] - $parity_r200[1] - $parity_r200[2]
    $parity_r201_diff = $parity_r200[0] + $parity_r200[2] - $parity_r200[1] - $parity_r200[3]

    #T が最低何個必要か求める
    $parity_T_min = [math]::Abs($parity_r211_diff / 2)

    #入力された T の個数について偶奇が間違っているならば 1 を減算する
    if(($pieces_counter[4] + $parity_T_min) % 2)
    {
        $pieces_counter[4]--
        $pieces_counter_sum--
    }

    #T が足りないならば解なしとして終了する
    if($parity_T_min -gt $pieces_counter[4])
    {
        $solutions_tetfu_splited.Add('Not Found')
        $solutions_tetfu_reduced.Add('Not Found')
        $solutions_tetfu_all.Add('Not Found')
    
        return @{num = $num_of_solutions; all = $solutions_tetfu_all ; split = $solutions_tetfu_splited; reduce = $solutions_tetfu_reduced}
    }

    #ミノが足りなければ、解なしとして終了する
    if($pieces_counter_sum -lt $need_pieces)
    {
        $solutions_tetfu_splited.Add('Not Found')
        $solutions_tetfu_reduced.Add('Not Found')
        $solutions_tetfu_all.Add('Not Found')
    
        return @{num = $num_of_solutions; all = $solutions_tetfu_all ; split = $solutions_tetfu_splited; reduce = $solutions_tetfu_reduced}
    }

    #T の必要個数と入力個数が一致する場合、T の置き方を絞り込める
    if($parity_T_min -and ($parity_T_min -eq $pieces_counter[4]))
    {
        #T の置き方の候補をフィルターする
        $placement_list = $placement_list.FindAll([Predicate[object]]{ param($x) -not (($x.piece_id -ge 16) -and ((($x.location % 10) + [math]::Floor($x.location / 10) + ($parity_r211_diff -gt 0)) % 2)) })
    }

    #JL の個数が確定する場合、T 縦の個数の偶奇が確定する
    #このうち、T が 1 個の場合においては T の置き方を絞り込める
    if(($pieces_counter_sum -eq $need_pieces) -and ($pieces_counter[4] -eq 1))
    {
        #true なら縦
        if([bool]($parity_r201_diff % 4))
        {
            $placement_list = $placement_list.FindAll([Predicate[object]]{ param($x) (($x.piece_id -ne 16) -and ($x.piece_id -ne 18))})
        }
        #false なら横
        else
        {
            $placement_list = $placement_list.FindAll([Predicate[object]]{ param($x) (($x.piece_id -ne 17) -and ($x.piece_id -ne 19))})
        }
    }
    #パリティ関連処理ここまで
    #--------------------

    #置き方がないので解なしとして終了する
    if($placement_list.Count -eq 0)
    {
        $solutions_tetfu_splited.Add('Not Found')
        $solutions_tetfu_reduced.Add('Not Found')
        $solutions_tetfu_all.Add('Not Found')
    
        return @{num = $num_of_solutions; all = $solutions_tetfu_all ; split = $solutions_tetfu_splited; reduce = $solutions_tetfu_reduced}
    }

    #セルごとに置き方が何通りあるかの一覧を返す
    [List[Int]]$placement_count_by_cell = Count_Placements_By_Cell $placement_list $field_to_fill_hashset

    #置き方が最も少ないセルの置き方が何通りあるか取得する
    #同時に、置き方が最も少ないセルの位置を取得する
    $min = 100
    switch($field_to_fill_hashset)
    {
        default
        {
            if($placement_count_by_cell[$_] -lt $min)
            {
                $min = $placement_count_by_cell[$_]
                $tgt_index = $_
            }
        }
    }


    #埋められないマスがあるので解なしとして終了
    if($min -eq 0)
    {
        $solutions_tetfu_splited.Add('Not Found')
        $solutions_tetfu_reduced.Add('Not Found')
        $solutions_tetfu_all.Add('Not Found')
    
        return @{num = $num_of_solutions; all = $solutions_tetfu_all ; split = $solutions_tetfu_splited; reduce = $solutions_tetfu_reduced}
    }

    #---------------------
    #記憶領域確保
    $placement_buff = New-Object List[List[Object]]($need_pieces + 1)

    $current_placement = New-Object List[Object]($need_pieces + 1)

    #$placement_buff[0] なら、0 ミノ置いた状態を記憶している

    $placement_buff.Add([List[Object]]::new())
    $placement_buff[-1].AddRange($placement_list)

    #---------------------
    #各要素についてループする

    switch($placement_buff[-1])
    {
        default
        {
            #置き方が最も少ないセルに置く方法を試す
            if( ($_.filled_cells).Contains($tgt_index) )
            {
                $placement_list.Clear()
                $placement_list.AddRange($placement_buff[-1])
                
                place_piece
            }
        }
    }

    #--------------------------------------------------
    #以下、アウトプットにかかわる部分
    if($solutions_table.Count -eq 0)
    {
        $solutions_tetfu_splited.Add('Not Found')
        $solutions_tetfu_reduced.Add('Not Found')
        $solutions_tetfu_all.Add('Not Found')
    }
    else
    {
        $num_of_solutions = $solutions_table.Count

        $exist_blocks_in_base = $field_base.Exists([Predicate[int]]{ param($x) $x -gt 0})
        
        $splited_str_base = TSolver_EFL_EditFumen_TableToRaw @([object]@{field_current = $field_base; field_updated = $field_base; piece = 0; rotation = 0; location = 0; flag_raise = 0; flag_mirror = 0; flag_color = 1; flag_comment = 0; flag_lock = 1; comment_current_length = 0; comment_current = ''; comment_updated_length = 0; comment_updated = '';})
        $splited_str_base = $splited_str_base.Remove($splited_str_base.Length - 3)

        $splited_str_length = $splited_str_base.Length + ($need_pieces + $exist_blocks_in_base) * 3
        $splited_str_? = [math]::Floor($splited_str_length / 47)
        $splited_str_length += $splited_str_?

        $data_list_all = New-Object List[Object]($num_of_solutions)

        #各解について
        foreach($i in 0..($num_of_solutions - 1))
        {
            $data_list_reduced = New-Object List[Object](1)

            $reduced_field_current = New-Object List[int]([List[int[]]]$field_base)

            $splited_str_builder = New-Object System.Text.StringBuilder($splited_str_base, $splited_str_length)

            #1 手ずつ確認する
            foreach($j in 0..($need_pieces - 1))
            {
                #splited のデータを編集

                #ライン消去が入ったら足す
                $location_converter = 0
            
                #下にある各段が埋まっているかに基づく処理
                for($k = 0; $k -lt [math]::Floor($solutions_table[$i][$j].location / 10); $k++)
                {
                    #埋まっていたら $location_converter をインクリメント
                    if(-not ([List[Int]]$reduced_field_current[(-11 + 10 * $k)..(-20 + 10 * $k)]).Contains(0))
                    {
                        $location_converter++
                    }
                }

                $splited_str_builder = $splited_str_builder.Append((TSolver_EFL_ValueToBase64 ($solutions_table[$i][$j].piece_no + $solutions_table[$i][$j].rotation_no * 8 + ($solutions_table[$i][$j].location + 10 * $location_converter) * 32 + 30720) 3))

                #reduced のデータを編集
                foreach($cells in $solutions_table[$i][$j].filled_cells)
                {
                    $reduced_field_current[$cells] = $solutions_table[$i][$j].piece_no
                }
            }

            #split 後処理
            if($splited_str_builder.ToString(5, 2).Equals('vh'))
            {
                #vh の後をいじる
                $splited_str_builder[7] = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.Substring(($need_pieces - 1) % 64, 1)
            }
            else
            {
                #vh を挿入する
                $splited_str_builder = $splited_str_builder.Insert($splited_str_base.Length, 'vh' + 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.Substring(($need_pieces - 2) % 64, 1))
            }
            #? を挿入する
            for($i = 0; (48 * $i + 47) -le ($splited_str_builder.Length); $i++)
            {
                $splited_str_builder = $splited_str_builder.Insert(48 * $i + 47, '?')
            }
            
            #reduce のフィールドの更新
            $reduced_field_updated = New-Object List[int]([List[int[]]]$reduced_field_current)
            $reduced_field_updated = TSolver_EFL_EditTable_UpdateField $reduced_field_updated 0 0 0 1 0 0
            
            $data_list_reduced.Add([object]@{field_current = $reduced_field_current; field_updated = $reduced_field_updated; piece = 0; rotation = 0; location = 0; flag_raise = 0; flag_mirror = 0; flag_color = 1; flag_comment = 0; flag_lock = 1; comment_current_length = 0; comment_current = ''; comment_updated_length = 0; comment_updated = '';})
            $data_list_all.Add([object]@{field_current = $reduced_field_current; field_updated = $reduced_field_updated; piece = 0; rotation = 0; location = 0; flag_raise = 0; flag_mirror = 0; flag_color = 1; flag_comment = 0; flag_lock = 1; comment_current_length = 0; comment_current = ''; comment_updated_length = 0; comment_updated = '';})
            
            #テト譜の追加
            $solutions_tetfu_splited.Add($splited_str_builder.ToString())
            $solutions_tetfu_reduced.Add((TSolver_EFL_EditFumen_TableToRaw $data_list_reduced))
        }

        $solutions_tetfu_all.Add((TSolver_EFL_EditFumen_TableToRaw $data_list_all))
    }
    
    return @{num = $num_of_solutions; all = $solutions_tetfu_all ; split = $solutions_tetfu_splited; reduce = $solutions_tetfu_reduced}

}

