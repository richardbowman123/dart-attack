$src = "C:\Users\r_a_b\OneDrive - This Is Insight\Claude Code work\experiments\games\Dart Attack\web-export"
$dst = "C:\Users\r_a_b\OneDrive - This Is Insight\Claude Code work\experiments\games\Dart Attack\docs"

Get-ChildItem "$src\Dart Attack.*" | ForEach-Object {
    $newName = $_.Name -replace '^Dart Attack', 'index'
    Copy-Item $_.FullName -Destination (Join-Path $dst $newName) -Force
    Write-Output "Copied: $($_.Name) -> $newName"
}

# Verify .pck sizes match
$srcPck = Get-Item "$src\Dart Attack.pck"
$dstPck = Get-Item "$dst\index.pck"
Write-Output ""
Write-Output "PCK size check:"
Write-Output "  web-export/Dart Attack.pck = $($srcPck.Length) bytes"
Write-Output "  docs/index.pck             = $($dstPck.Length) bytes"
if ($srcPck.Length -eq $dstPck.Length) {
    Write-Output "  MATCH - copy verified!"
} else {
    Write-Output "  WARNING: sizes don't match!"
}
