#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false

$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present"
$name = Get-AnsibleParam -obj $params -name "name" -type "str" -failifempty $true
$nodes = Get-AnsibleParam -obj $params -name "nodes" -type "list"
$administrative_access_point = Get-AnsibleParam -obj $params -name "administrative_access_point" -type "str" -default "ActiveDirectoryAndDns"
$management_point_network_type = Get-AnsibleParam -obj $params -name "management_point_network_type" -type "str" -default "Singleton"
$static_addresses = Get-AnsibleParam -obj $params -name "static_addresses" -type "list"
$no_storage = Get-AnsibleParam -obj $params -name "no_storage" -type "bool" -default $true

$result = @{
    changed = $false
    exists = $false
    name = ""
}

if ($state -notin @("present", "absent")) {
    Fail-Json -obj $result -message "Unsupported state '$state'"
}

function Get-CurrentCluster {
    $current_cluster = Get-Cluster -ErrorAction SilentlyContinue
    if (-not $current_cluster) {
        $current_cluster = Get-Cluster -Name $name -ErrorAction SilentlyContinue
    }
    return $current_cluster
}

$cluster = Get-CurrentCluster

if ($state -eq "absent") {
    if (-not $cluster) {
        Exit-Json -obj $result
    }

    $result.changed = $true
    $result.name = [string]$cluster.Name

    if (-not $check_mode) {
        Remove-Cluster -Force | Out-Null
    }

    $result.exists = $false
    Exit-Json -obj $result
}

if (-not $nodes -or $nodes.Count -eq 0) {
    Fail-Json -obj $result -message "nodes is required when state=present"
}

if ($cluster) {
    $result.exists = $true
    $result.name = [string]$cluster.Name
    Exit-Json -obj $result
}

$result.changed = $true
$result.exists = $true
$result.name = $name

if ($check_mode) {
    Exit-Json -obj $result
}

$cluster_params = @{
    Name = $name
    Node = @($nodes)
    AdministrativeAccessPoint = $administrative_access_point
    ManagementPointNetworkType = $management_point_network_type
}

if ($no_storage) {
    $cluster_params.NoStorage = $true
}

if ($management_point_network_type -ne "Distributed" -and $static_addresses -and $static_addresses.Count -gt 0) {
    $cluster_params.StaticAddress = @($static_addresses)
}

New-Cluster @cluster_params | Out-Null

Exit-Json -obj $result
