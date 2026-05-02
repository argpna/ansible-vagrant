#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false

$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present"
$ca_type = Get-AnsibleParam -obj $params -name "ca_type" -type "str" -default "EnterpriseRootCa"
$crypto_provider_name = Get-AnsibleParam -obj $params -name "crypto_provider_name" -type "str" -default "RSA#Microsoft Software Key Storage Provider"
$key_length = Get-AnsibleParam -obj $params -name "key_length" -type "int" -default 2048
$hash_algorithm_name = Get-AnsibleParam -obj $params -name "hash_algorithm_name" -type "str" -default "SHA256"

$result = @{
    changed = $false
    configured = $false
    ca_names = @()
}

if ($state -ne "present") {
    Fail-Json -obj $result -message "Unsupported state '$state'"
}

$cfg_path = 'HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration'
$ca_keys = @()
if (Test-Path $cfg_path) {
    $ca_keys = Get-ChildItem $cfg_path -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -ne 'Configuration' } |
        Select-Object -ExpandProperty PSChildName
}

if ($ca_keys.Count -eq 0) {
    if (-not $check_mode) {
        Install-AdcsCertificationAuthority `
            -CAType $ca_type `
            -CryptoProviderName $crypto_provider_name `
            -KeyLength $key_length `
            -HashAlgorithmName $hash_algorithm_name `
            -Force | Out-Null
    }

    $result.changed = $true

    $ca_keys = @()
    if (Test-Path $cfg_path) {
        $ca_keys = Get-ChildItem $cfg_path -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -ne 'Configuration' } |
            Select-Object -ExpandProperty PSChildName
    }
}

$result.configured = $ca_keys.Count -gt 0
$result.ca_names = @($ca_keys)

Exit-Json -obj $result
