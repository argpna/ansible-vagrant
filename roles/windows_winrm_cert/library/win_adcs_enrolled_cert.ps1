#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true

$issuer = Get-AnsibleParam -obj $params -name "issuer" -type "str" -default ""
$dns_name = Get-AnsibleParam -obj $params -name "dns_name" -type "str" -default ""
$require_client_auth = Get-AnsibleParam -obj $params -name "require_client_auth" -type "bool" -default $false
$require_server_auth = Get-AnsibleParam -obj $params -name "require_server_auth" -type "bool" -default $false
$exclude_kdc_auth = Get-AnsibleParam -obj $params -name "exclude_kdc_auth" -type "bool" -default $false

$result = @{
    changed = $false
    exists = $false
    issuer = $issuer
    thumbprint = ""
    subject = ""
}

$certificates = Get-ChildItem -Path Cert:\LocalMachine\My\ | Where-Object {
    $eku_names = @($_.EnhancedKeyUsageList | ForEach-Object { $_.FriendlyName })
    $dns_names = @($_.DnsNameList | ForEach-Object { $_.Unicode })

    if ($issuer -and $_.Issuer -ne $issuer) {
        return $false
    }
    if ($dns_name -and $dns_name -notin $dns_names) {
        return $false
    }
    if ($require_client_auth -and "Client Authentication" -notin $eku_names) {
        return $false
    }
    if ($require_server_auth -and "Server Authentication" -notin $eku_names) {
        return $false
    }
    if ($exclude_kdc_auth -and "KDC Authentication" -in $eku_names) {
        return $false
    }

    return $true
}

$certificate = $certificates | Select-Object -First 1
if ($certificate) {
    $result.exists = $true
    $result.thumbprint = $certificate.Thumbprint
    $result.subject = $certificate.Subject
}

Exit-Json -obj $result
