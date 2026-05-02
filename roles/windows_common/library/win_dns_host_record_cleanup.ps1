#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$zone_name = Get-AnsibleParam -obj $params -name "zone_name" -type "str" -failifempty $true
$record_name = Get-AnsibleParam -obj $params -name "record_name" -type "str" -failifempty $true
$expected_ip = Get-AnsibleParam -obj $params -name "expected_ip" -type "str" -failifempty $true

$result = @{
    changed = $false
    zone_name = $zone_name
    record_name = $record_name
    expected_ip = $expected_ip
    removed_ips = @()
}

$records = @(Get-DnsServerResourceRecord `
    -ZoneName $zone_name `
    -Name $record_name `
    -RRType A `
    -ErrorAction SilentlyContinue)

foreach ($record in $records) {
    $record_ip = $record.RecordData.IPv4Address.IPAddressToString
    if ($record_ip -ne $expected_ip) {
        $result.changed = $true
        $result.removed_ips += [string]$record_ip

        if (-not $check_mode) {
            Remove-DnsServerResourceRecord `
                -ZoneName $zone_name `
                -InputObject $record `
                -Force `
                -ErrorAction Stop
        }
    }
}

Exit-Json -obj $result
