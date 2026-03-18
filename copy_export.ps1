$src = "C:\Users\r_a_b\OneDrive - This Is Insight\Claude Code work\experiments\games\Dart Attack\web-export"
$dst = "C:\Users\r_a_b\OneDrive - This Is Insight\Claude Code work\experiments\games\Dart Attack\docs"

Get-ChildItem $src -Filter "Dart Attack.*" | ForEach-Object {
    $newName = $_.Name.Replace("Dart Attack", "index")
    Copy-Item $_.FullName -Destination (Join-Path $dst $newName) -Force
    Write-Output ("Copied: " + $_.Name + " -> " + $newName)
}

# Also copy the worklet files (no rename needed)
Copy-Item (Join-Path $src "Dart Attack.audio.worklet.js") -Destination (Join-Path $dst "Dart Attack.audio.worklet.js") -Force
Copy-Item (Join-Path $src "Dart Attack.audio.position.worklet.js") -Destination (Join-Path $dst "Dart Attack.audio.position.worklet.js") -Force

# Verify .pck size matches
$srcSize = (Get-Item (Join-Path $src "Dart Attack.pck")).Length
$dstSize = (Get-Item (Join-Path $dst "index.pck")).Length
Write-Output ""
Write-Output ("Source .pck: " + $srcSize + " bytes")
Write-Output ("Dest   .pck: " + $dstSize + " bytes")
if ($srcSize -eq $dstSize) { Write-Output "PCK SIZE MATCH - OK" } else { Write-Output "PCK SIZE MISMATCH - ERROR" }
