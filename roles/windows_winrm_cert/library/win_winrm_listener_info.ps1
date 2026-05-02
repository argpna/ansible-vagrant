#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true

$result = @{
    changed = $false
    exists = $false
    certificate_thumbprint = ""
    address = ""
}

$https_listener = Get-Item -Path WSMan:\localhost\Listener\* |
    Where-Object { "Transport=HTTPS" -in $_.Keys } |
    Select-Object -First 1

if (-not $https_listener) {
    Exit-Json -obj $result
}

$address = (
    $https_listener.Keys |
        Where-Object { $_.StartsWith("Address=") }
).Split("=")[-1]

$wsman_instance = Get-WSManInstance `
    -ResourceURI winrm/config/listener `
    -SelectorSet @{
        Transport = "HTTPS"
        Address = $address
    }

$result.exists = $true
$result.address = $address
$result.certificate_thumbprint = $wsman_instance.CertificateThumbprint

Exit-Json -obj $result
