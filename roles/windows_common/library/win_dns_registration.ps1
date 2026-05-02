#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$adapter_name = Get-AnsibleParam -obj $params -name "adapter_name" -type "str" -failifempty $true

$result = @{
    changed = $false
    adapter_name = $adapter_name
    updated_interfaces = @()
}

$clients = @(Get-DnsClient | Where-Object {
    $_.InterfaceAlias -and
    $_.InterfaceAlias -ne "Loopback Pseudo-Interface 1"
})

if ($clients.Count -eq 0) {
    Fail-Json -obj $result -message "No DNS client interfaces were found"
}

$target_client = $clients |
    Where-Object { $_.InterfaceAlias -eq $adapter_name } |
    Select-Object -First 1

if (-not $target_client) {
    Fail-Json -obj $result -message "DNS client interface '$adapter_name' was not found"
}

foreach ($client in $clients) {
    $should_register = ($client.InterfaceAlias -eq $adapter_name)
    if ([bool]$client.RegisterThisConnectionsAddress -ne $should_register) {
        $result.changed = $true
        $result.updated_interfaces += [string]$client.InterfaceAlias

        if (-not $check_mode) {
            Set-DnsClient `
                -InterfaceIndex $client.InterfaceIndex `
                -RegisterThisConnectionsAddress $should_register `
                -ErrorAction Stop | Out-Null
        }
    }
}

Exit-Json -obj $result
