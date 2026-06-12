# Copy updated grub.cfg to the USB boot partition (run elevated).
$ErrorActionPreference = "Stop"
$Base = "C:\Users\Surface\Desktop\ubuntu-surface"
Start-Transcript -Path "$Base\usb-grub-update.log" -Force
try {
    Copy-Item "$Base\build-output\esp\grub.cfg" "D:\EFI\BOOT\grub.cfg" -Force
    Copy-Item "$Base\build-output\esp\grub.cfg" "D:\EFI\fedora\grub.cfg" -Force
    Get-Item "D:\EFI\BOOT\grub.cfg" | Select-Object FullName, Length, LastWriteTime
    Write-Output "=== GRUB UPDATE DONE"
} catch {
    Write-Output "FAILED: $_"
} finally {
    Stop-Transcript
}
