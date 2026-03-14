$srcDir = "C:\Users\r_a_b\OneDrive - This Is Insight\Claude Code work\experiments\games\Dart Attack\web-export"
$dstDir = "C:\Users\r_a_b\OneDrive - This Is Insight\Claude Code work\experiments\games\Dart Attack\docs"

Get-ChildItem $srcDir -File | ForEach-Object {
    $newName = $_.Name -replace 'Dart Attack', 'index'
    Copy-Item $_.FullName -Destination (Join-Path $dstDir $newName)
}

Write-Host "Done - copied and renamed files to docs/"
