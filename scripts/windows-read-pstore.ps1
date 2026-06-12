# Read Linux pstore crash dumps from EFI variables (run elevated).
# pstore-efi vars live under LINUX_EFI_CRASH_GUID cfc8fc79-be2e-4ddc-97f0-9f98bfe298a0
$ErrorActionPreference = "Continue"
$Base = "C:\Users\Surface\Desktop\ubuntu-surface"
Start-Transcript -Path "$Base\pstore-read.log" -Force

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class EfiVars {
  [DllImport("ntdll.dll")]
  public static extern int NtEnumerateSystemEnvironmentValuesEx(uint cls, IntPtr buf, ref uint len);
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern uint GetFirmwareEnvironmentVariable(string name, string guid, IntPtr buf, uint size);
  [DllImport("advapi32.dll", SetLastError=true)]
  public static extern bool OpenProcessToken(IntPtr h, uint acc, out IntPtr tok);
  [DllImport("advapi32.dll", SetLastError=true)]
  public static extern bool LookupPrivilegeValue(string sys, string name, out long luid);
  [DllImport("advapi32.dll", SetLastError=true)]
  public static extern bool AdjustTokenPrivileges(IntPtr tok, bool dis, ref TOKEN_PRIVILEGES tp, uint len, IntPtr prev, IntPtr ret);
  [DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();
  [StructLayout(LayoutKind.Sequential)]
  public struct TOKEN_PRIVILEGES { public uint Count; public long Luid; public uint Attr; }
}
'@

# enable SeSystemEnvironmentPrivilege
$tok = [IntPtr]::Zero
[EfiVars]::OpenProcessToken([EfiVars]::GetCurrentProcess(), 0x28, [ref]$tok) | Out-Null
$luid = 0L
[EfiVars]::LookupPrivilegeValue($null, "SeSystemEnvironmentPrivilege", [ref]$luid) | Out-Null
$tp = New-Object EfiVars+TOKEN_PRIVILEGES
$tp.Count = 1; $tp.Luid = $luid; $tp.Attr = 2
[EfiVars]::AdjustTokenPrivileges($tok, $false, [ref]$tp, 0, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null

# enumerate all variable names (class 1 = names only)
$len = [uint32]0
[EfiVars]::NtEnumerateSystemEnvironmentValuesEx(1, [IntPtr]::Zero, [ref]$len) | Out-Null
$buf = [Runtime.InteropServices.Marshal]::AllocHGlobal([int]$len)
$r = [EfiVars]::NtEnumerateSystemEnvironmentValuesEx(1, $buf, [ref]$len)
Write-Output "enum status=$r len=$len"

# walk VARIABLE_NAME entries: ULONG NextEntryOffset; GUID VendorGuid; WCHAR Name[];
$pstoreVars = @()
$off = 0
while ($true) {
    $next = [Runtime.InteropServices.Marshal]::ReadInt32($buf, $off)
    $gbytes = New-Object byte[] 16
    [Runtime.InteropServices.Marshal]::Copy([IntPtr]::Add($buf, $off+4), $gbytes, 0, 16)
    $guid = New-Object Guid (,$gbytes)
    $name = [Runtime.InteropServices.Marshal]::PtrToStringUni([IntPtr]::Add($buf, $off+20))
    if ($guid -eq [Guid]"cfc8fc79-be2e-4ddc-97f0-9f98bfe298a0") {
        $pstoreVars += @{ Name = $name; Guid = $guid }
        Write-Output "PSTORE VAR: $name"
    }
    if ($next -eq 0) { break }
    $off += $next
}
[Runtime.InteropServices.Marshal]::FreeHGlobal($buf)
Write-Output ("pstore vars found: {0}" -f $pstoreVars.Count)

$i = 0
foreach ($v in $pstoreVars) {
    $vb = [Runtime.InteropServices.Marshal]::AllocHGlobal(65536)
    $n = [EfiVars]::GetFirmwareEnvironmentVariable($v.Name, "{cfc8fc79-be2e-4ddc-97f0-9f98bfe298a0}", $vb, 65536)
    if ($n -gt 0) {
        $data = New-Object byte[] $n
        [Runtime.InteropServices.Marshal]::Copy($vb, $data, 0, $n)
        $out = "$Base\pstore-$i-$($v.Name).bin"
        [IO.File]::WriteAllBytes($out, $data)
        Write-Output "saved $out ($n bytes)"
        $i++
    } else {
        Write-Output "read failed: $($v.Name) err=$([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }
    [Runtime.InteropServices.Marshal]::FreeHGlobal($vb)
}
Write-Output "=== PSTORE READ DONE"
Stop-Transcript
