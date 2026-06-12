# Rewrite USB rootfs partition with updated image + refresh grub.cfg (elevated).
$ErrorActionPreference = "Stop"
$Base = "C:\Users\Surface\Desktop\ubuntu-surface"
Start-Transcript -Path "$Base\usb-rewrite.log" -Force
try {
    Write-Output "=== [1/2] grub.cfg"
    Copy-Item "$Base\build-output\esp\grub.cfg" "D:\EFI\BOOT\grub.cfg" -Force
    Copy-Item "$Base\build-output\esp\grub.cfg" "D:\EFI\fedora\grub.cfg" -Force

    Write-Output "=== [2/2] rewrite rootfs partition"
    $part = Get-Partition -DiskNumber 1 -PartitionNumber 2
    if ($part.GptType -ne "{0fc63daf-8483-4772-8e79-3d69d8477de4}") { throw "partition 2 is not the Linux partition" }
    $img = "\\wsl.localhost\Ubuntu\root\spx-rootfs.img"
    $imgLen = (Get-Item $img).Length
    $dev = "\\?\GLOBALROOT\Device\Harddisk1\Partition2"
    $src = [IO.File]::OpenRead($img)
    $dst = New-Object IO.FileStream($dev, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::None, 1MB, [IO.FileOptions]::WriteThrough)
    $buf = New-Object byte[] (4MB)
    $total = 0; $sw = [Diagnostics.Stopwatch]::StartNew()
    while (($n = $src.Read($buf, 0, $buf.Length)) -gt 0) {
        if ($n % 4096 -ne 0) { for ($i=$n; $i -lt $buf.Length; $i++){ $buf[$i]=0 }; $n = [math]::Ceiling($n/4096)*4096 }
        $dst.Write($buf, 0, $n); $total += $n
        if ($total % 2GB -eq 0) { Write-Output ("written {0:N0} GiB / 8" -f ($total/1GB)) }
    }
    $dst.Flush(); $dst.Close(); $src.Close()
    Write-Output ("Wrote {0:N0} bytes in {1:N0}s" -f $total, $sw.Elapsed.TotalSeconds)
    Write-Output "=== REWRITE DONE"
} catch {
    Write-Output "FAILED: $_"
} finally {
    Stop-Transcript
}
