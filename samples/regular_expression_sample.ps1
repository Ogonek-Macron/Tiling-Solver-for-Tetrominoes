#悪意ある入力による攻撃から守るためのサンプルコード
#T-Solver Ver 0.3 時点

#最初のピリオドより右側について
$StrTest = 'all.Chunk(100).HardDropView()'


#これに通して True ならば実行してよい
$StrTest -match '^(num|((split|reduce|all(|\.chunk\([0-9]*[1-9][0-9]*\)))(|\.Raw\(\)|\.URL\(\)|\.Edit\(\)|\.ListFull\(\)|\.List\(\)|\.ListMin\(\)|\.View\(\)|\.Mobile\(\)|\.HardDrop\(\)|\.HardDropList\(\)|\.HardDropView\(\))))$'

#PowerShell の -match では正規表現の大文字小文字をデフォルトで区別しないので、これで OK
