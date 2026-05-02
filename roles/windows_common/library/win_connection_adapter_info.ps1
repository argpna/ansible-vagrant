#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true
$address = Get-AnsibleParam -obj $params -name "address" -type "str" -failifempty $true

$adapter_names = @()

foreach ($instance in Get-CimInstance -ClassName Win32_NetworkAdapter -Filter "NetEnabled='True'") {
    $instance_config = Get-CimInstance `
        -ClassName Win32_NetworkAdapterConfiguration `
        -Filter "Index = '$($instance.Index)'"

    if ($instance_config.IPAddress -contains $address) {
        $adapter_names += [string]$instance.NetConnectionID
    }
}

$result = @{
    changed = $false
    address = $address
    adapter_names = @($adapter_names)
    adapter_count = @($adapter_names).Count
}

Exit-Json -obj $result
