# Surface Pro X Linux boot USB setup (run elevated). WIPES USB DISK 1.
# P1: 512MB FAT32 boot (GRUB + kernel + dtb)   P2: rest, raw ext4 rootfs image
# Log: C:\Users\Surface\Desktop\ubuntu-surface\usb-setup.log
$ErrorActionPreference = "Stop"
$Base = "C:\Users\Surface\Desktop\ubuntu-surface"
Start-Transcript -Path "$Base\usb-setup.log" -Force

try {
    Write-Output "=== [1/5] safety check"
    $disk = Get-Disk -Number 1
    if ($disk.BusType -ne "USB") { throw "disk 1 is not USB (BusType=$($disk.BusType))" }
    if ($disk.Size -gt 20GB)     { throw "disk 1 larger than expected ($($disk.Size))" }
    Write-Output ("wiping disk 1: {0} {1:N1} GB" -f $disk.FriendlyName, ($disk.Size/1GB))

    Write-Output "=== [2/5] partition"
    Clear-Disk -Number 1 -RemoveData -RemoveOEM -Confirm:$false
    Initialize-Disk -Number 1 -PartitionStyle GPT -ErrorAction SilentlyContinue
    $boot = New-Partition -DiskNumber 1 -Size 512MB -AssignDriveLetter
    Format-Volume -DriveLetter $boot.DriveLetter -FileSystem FAT32 -NewFileSystemLabel SPXBOOT -Confirm:$false | Out-Null
    # mark as ESP after formatting (some firmware also boots plain FAT32+BOOTAA64)
    $boot | Set-Partition -GptType "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" -ErrorAction SilentlyContinue
    $root = New-Partition -DiskNumber 1 -UseMaximumSize -GptType "{0fc63daf-8483-4772-8e79-3d69d8477de4}"
    Write-Output ("boot=P{0} ({1}:)  root=P{2} {3:N0} bytes" -f $boot.PartitionNumber, $boot.DriveLetter, $root.PartitionNumber, $root.Size)

    Write-Output "=== [3/5] boot files"
    $L = $boot.DriveLetter
    New-Item -ItemType Directory -Force "${L}:\EFI\BOOT", "${L}:\EFI\fedora" | Out-Null
    Copy-Item "$Base\build-output\esp\EFI\ubuntu\grubaa64.efi" "${L}:\EFI\BOOT\BOOTAA64.EFI" -Force
    Copy-Item "$Base\build-output\esp\grub.cfg" "${L}:\EFI\BOOT\" -Force
    Copy-Item "$Base\build-output\esp\grub.cfg" "${L}:\EFI\fedora\" -Force
    Copy-Item "$Base\build-output\esp\Image.gz" "${L}:\" -Force
    Copy-Item "$Base\build-output\esp\sc8180xp-microsoft-surface-pro-x.dtb" "${L}:\" -Force
    Get-ChildItem -Recurse "${L}:\" | Select-Object FullName, Length | Format-Table -AutoSize

    Write-Output "=== [4/5] raw-write rootfs image (8 GiB, takes a few minutes)"
    $img = "\\wsl.localhost\Ubuntu\root\spx-rootfs.img"
    $imgLen = (Get-Item $img).Length
    if ($imgLen -gt $root.Size) { throw "image larger than partition" }
    $dev = "\\?\GLOBALROOT\Device\Harddisk1\Partition$($root.PartitionNumber)"
    Write-Output "src=$img ($imgLen) -> dst=$dev"
    $src = [IO.File]::OpenRead($img)
    $dst = New-Object IO.FileStream($dev, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::None, 1MB, [IO.FileOptions]::WriteThrough)
    $buf = New-Object byte[] (4MB)
    $total = 0; $sw = [Diagnostics.Stopwatch]::StartNew()
    while (($n = $src.Read($buf, 0, $buf.Length)) -gt 0) {
        if ($n % 4096 -ne 0) { for ($i=$n; $i -lt $buf.Length; $i++){ $buf[$i]=0 }; $n = [math]::Ceiling($n/4096)*4096 }
        $dst.Write($buf, 0, $n); $total += $n
        if ($total % 1GB -eq 0) { Write-Output ("written {0:N0} GiB / 8" -f ($total/1GB)) }
    }
    $dst.Flush(); $dst.Close(); $src.Close()
    Write-Output ("Wrote {0:N0} bytes in {1:N0}s ({2:N1} MB/s)" -f $total, $sw.Elapsed.TotalSeconds, ($total/1MB/$sw.Elapsed.TotalSeconds))

    Write-Output "=== [5/5] verify"
    Get-Partition -DiskNumber 1 | Select-Object PartitionNumber, Size, GptType | Format-Table -AutoSize
    Write-Output "=== USB DONE"
} catch {
    Write-Output "FAILED: $_"
} finally {
    Stop-Transcript
}
