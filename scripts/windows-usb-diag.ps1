# USB diagnostics + grub.cfg update (run elevated).
# 1) dump first 64KB of the ext4 partition (superblock evidence)
# 2) copy updated grub.cfg to the boot partition
$ErrorActionPreference = "Stop"
$Base = "C:\Users\Surface\Desktop\ubuntu-surface"
Start-Transcript -Path "$Base\usb-diag.log" -Force
try {
    Write-Output "=== [1/2] dump ext4 superblock region"
    $dev = "\\?\GLOBALROOT\Device\Harddisk1\Partition2"
    $src = New-Object IO.FileStream($dev, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $buf = New-Object byte[] 65536
    $n = $src.Read($buf, 0, $buf.Length); $src.Close()
    [IO.File]::WriteAllBytes("$Base\usb-p2-head.bin", $buf)
    Write-Output "dumped $n bytes -> usb-p2-head.bin"

    Write-Output "=== [2/2] update grub.cfg on boot partition"
    Copy-Item "$Base\build-output\esp\grub.cfg" "D:\EFI\BOOT\grub.cfg" -Force
    Copy-Item "$Base\build-output\esp\grub.cfg" "D:\EFI\fedora\grub.cfg" -Force
    Get-ChildItem -Recurse D:\ | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
    Write-Output "=== DIAG DONE"
} catch {
    Write-Output "FAILED: $_"
} finally {
    Stop-Transcript
}
