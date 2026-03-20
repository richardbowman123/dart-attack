$src = "C:\Users\r_a_b\OneDrive - This Is Insight\Claude Code work\experiments\games\Dart Attack\web-export"
$dst = "C:\Users\r_a_b\OneDrive - This Is Insight\Claude Code work\experiments\games\Dart Attack\docs"

Get-ChildItem $src -File | Where-Object { $_.Name -notmatch '\.import$' } | ForEach-Object {
    $newName = $_.Name -replace '^Dart Attack', 'index'
    Copy-Item $_.FullName -Destination (Join-Path $dst $newName) -Force
    Write-Output ("Copied: " + $_.Name + " -> " + $newName)
}
