# Surface Pro X dual-boot setup (run elevated).
# 1) BitLocker check/suspend  2) shrink C: by 30GiB  3) create Linux partition
# 4) raw-write rootfs image   5) stage ESP files      6) add firmware boot entry
# Log: C:\Users\Surface\Desktop\ubuntu-surface\dualboot-setup.log
$ErrorActionPreference = "Stop"
$Base = "C:\Users\Surface\Desktop\ubuntu-surface"
$Log  = "$Base\dualboot-setup.log"
Start-Transcript -Path $Log -Force

try {
    Write-Output "=== [1/6] BitLocker"
    $blv = Get-BitLockerVolume -MountPoint C: -ErrorAction SilentlyContinue
    if ($blv) {
        Write-Output ("VolumeStatus={0} Protection={1}" -f $blv.VolumeStatus, $blv.ProtectionStatus)
        if ($blv.ProtectionStatus -eq "On") {
            $rk = ($blv.KeyProtector | Where-Object KeyProtectorType -eq "RecoveryPassword").RecoveryPassword
            Write-Output "RecoveryKey(SAVE THIS): $rk"
            Suspend-BitLocker -MountPoint C: -RebootCount 0 | Out-Null
            Write-Output "BitLocker SUSPENDED (indefinite)"
        }
    } else { Write-Output "BitLocker: not enabled / not present" }

    Write-Output "=== [2/6] shrink C: by 30GiB"
    $part = Get-Partition -DriveLetter C
    $supported = Get-PartitionSupportedSize -DriveLetter C
    $newSize = $part.Size - 30GB
    if ($newSize -lt $supported.SizeMin) { throw "Cannot shrink 30GiB (min=$($supported.SizeMin))" }
    $existing = Get-Partition -DiskNumber 0 | Where-Object GptType -eq "{0fc63daf-8483-4772-8e79-3d69d8477de4}"
    if ($existing) {
        Write-Output "Linux partition already exists (#$($existing.PartitionNumber)) - skipping shrink"
        $linuxPart = $existing
    } else {
        Resize-Partition -DriveLetter C -Size $newSize
        Write-Output "C: resized to $newSize"
        Write-Output "=== [3/6] create Linux partition"
        $linuxPart = New-Partition -DiskNumber 0 -UseMaximumSize -GptType "{0fc63daf-8483-4772-8e79-3d69d8477de4}"
        Write-Output ("Created partition #{0} size {1:N0} offset {2}" -f $linuxPart.PartitionNumber, $linuxPart.Size, $linuxPart.Offset)
    }

    Write-Output "=== [4/6] raw-write rootfs image"
    $img = "\\wsl.localhost\Ubuntu\root\spx-rootfs.img"
    $imgLen = (Get-Item $img).Length
    $dev = "\\?\GLOBALROOT\Device\Harddisk0\Partition$($linuxPart.PartitionNumber)"
    Write-Output "src=$img ($imgLen bytes) -> dst=$dev"
    if ($imgLen -gt $linuxPart.Size) { throw "image larger than partition" }
    $src = [IO.File]::OpenRead($img)
    $dst = New-Object IO.FileStream($dev, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::None, 1MB, [IO.FileOptions]::WriteThrough)
    $buf = New-Object byte[] (4MB)
    $total = 0; $sw = [Diagnostics.Stopwatch]::StartNew()
    while (($n = $src.Read($buf, 0, $buf.Length)) -gt 0) {
        if ($n % 4096 -ne 0) { for ($i=$n; $i -lt $buf.Length; $i++){ $buf[$i]=0 }; $n = [math]::Ceiling($n/4096)*4096 }
        $dst.Write($buf, 0, $n); $total += $n
        if ($total % 512MB -eq 0) { Write-Output ("written {0:N0} MiB" -f ($total/1MB)) }
    }
    $dst.Flush(); $dst.Close(); $src.Close()
    Write-Output ("Wrote {0:N0} bytes in {1:N0}s" -f $total, $sw.Elapsed.TotalSeconds)

    Write-Output "=== [5/6] ESP files"
    $espLetter = "S"
    mountvol "${espLetter}:" /S
    New-Item -ItemType Directory -Force "${espLetter}:\EFI\ubuntu" | Out-Null
    Copy-Item "$Base\build-output\esp\EFI\ubuntu\grubaa64.efi" "${espLetter}:\EFI\ubuntu\" -Force
    Copy-Item "$Base\build-output\esp\grub.cfg" "${espLetter}:\EFI\ubuntu\" -Force
    New-Item -ItemType Directory -Force "${espLetter}:\EFI\fedora" | Out-Null
    Copy-Item "$Base\build-output\esp\grub.cfg" "${espLetter}:\EFI\fedora\" -Force
    Copy-Item "$Base\build-output\esp\Image.gz" "${espLetter}:\" -Force
    Copy-Item "$Base\build-output\esp\sc8180xp-microsoft-surface-pro-x.dtb" "${espLetter}:\" -Force
    Get-ChildItem -Recurse "${espLetter}:\EFI\ubuntu", "${espLetter}:\Image.gz" | Select-Object FullName, Length | Format-Table -AutoSize
    $espFree = (Get-Volume -FilePath "${espLetter}:\").SizeRemaining
    Write-Output "ESP free after copy: $espFree"
    mountvol "${espLetter}:" /D

    Write-Output "=== [6/6] firmware boot entry"
    $out = bcdedit /copy "{bootmgr}" /d "GRUB (Ubuntu)"
    if ($out -match '\{[0-9a-f-]+\}') { $guid = $Matches[0] } else { throw "bcdedit copy failed: $out" }
    bcdedit /set $guid path \EFI\ubuntu\grubaa64.efi
    bcdedit /set "{fwbootmgr}" displayorder $guid /addfirst
    Write-Output "Boot entry $guid added (first). With Secure Boot ON it is skipped; disable SB in Surface UEFI to use it."
    Write-Output "=== DONE"
} catch {
    Write-Output "FAILED: $_"
} finally {
    Stop-Transcript
}
