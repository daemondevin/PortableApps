# Bearsampp Portable: the development root certificate (mkcert's rootCA.pem)
# in the current user's Trusted Root Certification Authorities.
#   BearsamppRootCA.ps1 check <rootCA.pem>
#     Exit code 1 when that certificate is trusted, 0 when it isn't, 2 when
#     the file is missing or can't be read.
#   BearsamppRootCA.ps1 remove <rootCA.pem> [<rootCA.pem> ...]
#     Removes each certificate from the store. Windows asks for confirmation
#     before it removes a root certificate. Always exits 0: a file that is
#     gone or a certificate that isn't trusted means nothing is left to do.
$mode = $args[0]
$files = @($args | Select-Object -Skip 1)
$x509 = 'System.Security.Cryptography.X509Certificates'
if ($mode -eq 'check') {
	$file = $files[0]
	if (-not $file -or -not (Test-Path -LiteralPath $file)) { exit 2 }
	try { $cert = New-Object "$x509.X509Certificate2" $file } catch { exit 2 }
	$store = New-Object "$x509.X509Store" 'Root', 'CurrentUser'
	try { $store.Open('ReadOnly') } catch { exit 2 }
	$found = @($store.Certificates.Find('FindByThumbprint', $cert.Thumbprint, $false)).Count
	$store.Close()
	if ($found -gt 0) { exit 1 }
	exit 0
}
if ($mode -eq 'remove') {
	$store = New-Object "$x509.X509Store" 'Root', 'CurrentUser'
	try { $store.Open('ReadWrite') } catch { exit 0 }
	foreach ($file in $files) {
		if ($file -and (Test-Path -LiteralPath $file)) {
			try {
				$cert = New-Object "$x509.X509Certificate2" $file
				foreach ($match in @($store.Certificates.Find('FindByThumbprint', $cert.Thumbprint, $false))) {
					$store.Remove($match)
				}
			} catch {}
		}
	}
	$store.Close()
	exit 0
}
exit 2
