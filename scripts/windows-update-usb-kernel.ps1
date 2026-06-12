# Copy rebuilt Image.gz to the USB boot partition (run elevated).
$ErrorActionPreference = "Stop"
$Base = "C:\Users\Surface\Desktop\ubuntu-surface"
Start-Transcript -Path "$Base\usb-kernel-update.log" -Force
try {
    Copy-Item "$Base\build-output\Image.gz" "D:\Image.gz" -Force
    Get-Item "D:\Image.gz" | Select-Object FullName, Length, LastWriteTime
    Write-Output "=== KERNEL UPDATE DONE"
} catch {
    Write-Output "FAILED: $_"
} finally {
    Stop-Transcript
}
