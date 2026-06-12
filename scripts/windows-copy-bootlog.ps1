$ErrorActionPreference = "Continue"
$Base = "C:\Users\Surface\Desktop\ubuntu-surface"
Start-Transcript -Path "$Base\copy-bootlog.log" -Force
Get-Partition -DiskNumber 1 | Select-Object PartitionNumber, DriveLetter, AccessPaths | Format-List
$p1 = Get-Partition -DiskNumber 1 -PartitionNumber 1
$letter = $p1.DriveLetter
if (-not $letter) {
    $p1 | Add-PartitionAccessPath -AccessPath "S:\" -ErrorAction SilentlyContinue
    $letter = "S"
}
Get-ChildItem "${letter}:\" | Select-Object Name, Length, LastWriteTime
Copy-Item "${letter}:\spx-bootlog.txt" "$Base\spx-bootlog.txt" -Force
Get-Item "$Base\spx-bootlog.txt" | Select-Object Length, LastWriteTime
Write-Output "=== COPY DONE"
Stop-Transcript
