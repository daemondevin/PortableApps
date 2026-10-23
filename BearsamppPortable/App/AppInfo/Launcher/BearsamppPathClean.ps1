# Bearsampp Portable: takes %BEARSAMPP_BINS% out of the machine PATH again.
# Bearsampp puts it at the front of PATH when it starts; this runs when
# Bearsampp Portable closes, or on the next launch after a crash, and only
# when PATH didn't have it before. Every other entry is left exactly as it
# is, in the same order, and PATH stays an expandable string.
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true)
if ($key -eq $null) { exit 0 }
$old = $key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
$new = (@($old -split ';') | Where-Object { $_ -ne '%BEARSAMPP_BINS%' }) -join ';'
if ($new -ne $old) {
	$key.SetValue('Path', $new, [Microsoft.Win32.RegistryValueKind]::ExpandString)
}
$key.Close()
exit 0
