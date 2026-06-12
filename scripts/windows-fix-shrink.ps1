# Free up unmovable files blocking C: shrink, then report shrink headroom.
# Run elevated. Log: dualboot-shrink-fix.log
$ErrorActionPreference = "Continue"
$Base = "C:\Users\Surface\Desktop\ubuntu-surface"
Start-Transcript -Path "$Base\dualboot-shrink-fix.log" -Force

Write-Output "=== [1/5] before:"
$s = Get-PartitionSupportedSize -DriveLetter C
$cur = (Get-Partition -DriveLetter C).Size
Write-Output ("current={0:N0}  SizeMin={1:N0}  shrinkable={2:N1} GiB" -f $cur, $s.SizeMin, (($cur-$s.SizeMin)/1GB))

Write-Output "=== [2/5] hibernation off (removes hiberfil.sys)"
powercfg /h off

Write-Output "=== [3/5] shrink shadow storage"
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=512MB

Write-Output "=== [4/5] shutdown WSL (unlock vhdx) + defrag/consolidate"
wsl --shutdown
defrag C: /X /U

Write-Output "=== [5/5] after:"
$s2 = Get-PartitionSupportedSize -DriveLetter C
Write-Output ("SizeMin={0:N0}  shrinkable={1:N1} GiB" -f $s2.SizeMin, (($cur-$s2.SizeMin)/1GB))

# pagefile info (if this is the blocker a reboot will be needed after disabling)
Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize | Format-Table -AutoSize
Write-Output "=== SHRINKFIX DONE"
Stop-Transcript
