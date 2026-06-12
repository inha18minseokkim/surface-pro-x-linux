# Copy new kernel + minimal DTB + grub.cfg to USB boot partition (elevated).
$ErrorActionPreference = "Stop"
$Base = "C:\Users\Surface\Desktop\ubuntu-surface"
Start-Transcript -Path "$Base\usb-boot-update.log" -Force
try {
    $p1 = Get-Partition -DiskNumber 1 -PartitionNumber 1
    $L = $p1.DriveLetter
    if (-not $L) { $p1 | Add-PartitionAccessPath -AccessPath "S:\"; $L = "S" }
    Copy-Item "$Base\build-output\Image.gz" "${L}:\Image.gz" -Force
    Copy-Item "$Base\build-output\sc8180xp-spx-minimal.dtb" "${L}:\" -Force
    Copy-Item "$Base\build-output\esp\grub.cfg" "${L}:\EFI\BOOT\grub.cfg" -Force
    Copy-Item "$Base\build-output\esp\grub.cfg" "${L}:\EFI\fedora\grub.cfg" -Force
    Get-ChildItem "${L}:\" -File | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String | Write-Output
    Write-Output "=== BOOT UPDATE DONE"
} catch {
    Write-Output "FAILED: $_"
} finally {
    Stop-Transcript
}
