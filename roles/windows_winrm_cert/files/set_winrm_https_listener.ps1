param(
    [Parameter(Mandatory = $true)]
    [string]$CertificateThumbprint
)

$ErrorActionPreference = 'Stop'

$selector_set = @{
    Address   = '*'
    Transport = 'HTTPS'
}

$value_set = @{
    CertificateThumbprint = $CertificateThumbprint
    Enabled = $true
}

Get-ChildItem -Path WSMan:\localhost\Listener |
    Where-Object { $_.Keys -contains 'Transport=HTTPS' } |
    Remove-Item -Recurse -Force

New-WSManInstance `
    -ResourceURI winrm/config/listener `
    -SelectorSet $selector_set `
    -ValueSet $value_set | Out-Null
