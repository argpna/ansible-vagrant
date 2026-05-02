#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present"
$path = Get-AnsibleParam -obj $params -name "path" -type "str"

$result = @{
    changed = $false
    cluster_available = $true
    witness_resource_name = ""
    witness_share_path = ""
}

if ($state -notin @("present", "absent")) {
    Fail-Json -obj $result -message "Unsupported state '$state'"
}

try {
    $witness_resource = Get-ClusterResource |
        Where-Object { $_.ResourceType -eq 'File Share Witness' } |
        Select-Object -First 1
}
catch {
    if ($state -eq "absent") {
        $result.cluster_available = $false
        Exit-Json -obj $result
    }

    throw
}

if ($witness_resource) {
    $result.witness_resource_name = [string]$witness_resource.Name
    $share_path_parameter = Get-ClusterParameter -InputObject $witness_resource -Name SharePath -ErrorAction SilentlyContinue
    if ($share_path_parameter) {
        $result.witness_share_path = [string]$share_path_parameter.Value
    }
}

if ($state -eq "present") {
    if (-not $path) {
        Fail-Json -obj $result -message "path is required when state=present"
    }

    if ($result.witness_share_path -eq $path) {
        Exit-Json -obj $result
    }

    $result.changed = $true

    if (-not $check_mode) {
        Set-ClusterQuorum -FileShareWitness $path | Out-Null

        $witness_resource = Get-ClusterResource |
            Where-Object { $_.ResourceType -eq 'File Share Witness' } |
            Select-Object -First 1

        if ($witness_resource) {
            $result.witness_resource_name = [string]$witness_resource.Name
            $share_path_parameter = Get-ClusterParameter -InputObject $witness_resource -Name SharePath -ErrorAction SilentlyContinue
            if ($share_path_parameter) {
                $result.witness_share_path = [string]$share_path_parameter.Value
            }
        }
    }

    Exit-Json -obj $result
}

$should_remove = $false
if ($result.witness_resource_name) {
    if (-not $path) {
        $should_remove = $true
    }
    elseif ($result.witness_share_path -eq $path) {
        $should_remove = $true
    }
}

$result.changed = $should_remove

if ($should_remove -and -not $check_mode) {
    Set-ClusterQuorum -NodeMajority | Out-Null
    $result.witness_resource_name = ""
    $result.witness_share_path = ""
}

Exit-Json -obj $result
