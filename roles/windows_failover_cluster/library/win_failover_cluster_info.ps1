#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true
$name = Get-AnsibleParam -obj $params -name "name" -type "str"

$result = @{
    changed = $false
    exists = $false
    name = ""
    cluster_group_state = ""
    nodes = @()
}

$cluster = Get-Cluster -ErrorAction SilentlyContinue
if (-not $cluster -and $name) {
    $cluster = Get-Cluster -Name $name -ErrorAction SilentlyContinue
}

if (-not $cluster) {
    Exit-Json -obj $result
}

$cluster_group = Get-ClusterGroup -Name 'Cluster Group' -ErrorAction SilentlyContinue
$cluster_nodes = Get-ClusterNode | ForEach-Object {
    '{0}:{1}' -f $_.Name, $_.State
}

$result.exists = $true
$result.name = [string]$cluster.Name
$result.cluster_group_state = if ($cluster_group) { [string]$cluster_group.State } else { "" }
$result.nodes = @($cluster_nodes)

Exit-Json -obj $result
