#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false

$gpo_name = Get-AnsibleParam -obj $params -name "gpo_name" -type "str" -failifempty $true
$backup_path = Get-AnsibleParam -obj $params -name "backup_path" -type "str" -failifempty $true
$policy_server_id = Get-AnsibleParam -obj $params -name "policy_server_id" -type "str" -failifempty $true

$result = @{
    changed = $false
    gpo_name = $gpo_name
    policy_server_id = $policy_server_id
    policy_server_key = ""
}

function Get-NormalizedGpoRegistryValue {
    param(
        [string]$Name,
        [string]$Key,
        [string]$ValueName
    )

    try {
        $existing = Get-GPRegistryValue -Name $Name -Key $Key -ValueName $ValueName -ErrorAction Stop
    } catch {
        return $null
    }

    $value = $existing.Value
    $type = $existing.Type.ToString()
    if ($type -in @('String', 'ExpandString') -and
        $value -is [string] -and
        $value.EndsWith([char]0x0000)) {
        $value = $value.Substring(0, $value.Length - 1)
    }

    return @{
        value = $value
        type = $type
    }
}

function Ensure-GpoRegistryString {
    param(
        [string]$Name,
        [string]$Key,
        [string]$ValueName,
        [string]$Value
    )

    $existing = Get-NormalizedGpoRegistryValue -Name $Name -Key $Key -ValueName $ValueName
    if ($null -ne $existing -and $existing.type -eq 'String' -and $existing.value -eq $Value) {
        return
    }

    if (-not $check_mode) {
        Set-GPRegistryValue -Name $Name -Key $Key -ValueName $ValueName -Value $Value -Type String | Out-Null
    }
    $script:result.changed = $true
}

function Get-PolicyServerKeyPathFromBackup {
    param(
        [string]$Path
    )

    $gpo_report_path = Get-ChildItem -Path $Path -Recurse -Filter gpreport.xml -File |
        Select-Object -First 1 -ExpandProperty FullName

    if (-not $gpo_report_path) {
        Fail-Json -obj $result -message "Could not find gpreport.xml under backup path '$Path'"
    }

    [xml]$gpo_report = Get-Content -Path $gpo_report_path -Raw
    $key_path_node = Select-Xml `
        -Xml $gpo_report `
        -XPath "//*[local-name()='RegistrySetting'][*[local-name()='KeyPath' and starts-with(., 'Software\Policies\Microsoft\Cryptography\PolicyServers\')] and *[local-name()='Value']/*[local-name()='Name' and .='PolicyID']]/*[local-name()='KeyPath']" |
        Select-Object -First 1 -ExpandProperty Node

    if (-not $key_path_node) {
        Fail-Json -obj $result -message "Could not find PolicyID registry key path in backup report '$gpo_report_path'"
    }

    return "HKLM\$($key_path_node.InnerText)"
}

$gpo = Get-GPO -Name $gpo_name -ErrorAction SilentlyContinue
if (-not $gpo) {
    if (-not $check_mode) {
        Import-GPO -BackupGpoName $gpo_name -TargetName $gpo_name -Path $backup_path -CreateIfNeeded | Out-Null
        $gpo = Get-GPO -Name $gpo_name -ErrorAction Stop
    }
    $result.changed = $true
}

$policy_server_root = 'HKLM\Software\Policies\Microsoft\Cryptography\PolicyServers'
$policy_server_key = Get-PolicyServerKeyPathFromBackup -Path $backup_path
$result.policy_server_key = $policy_server_key

Ensure-GpoRegistryString -Name $gpo_name -Key $policy_server_root -ValueName '' -Value $policy_server_id
Ensure-GpoRegistryString -Name $gpo_name -Key $policy_server_key -ValueName 'PolicyID' -Value $policy_server_id

$target = (Get-ADRootDSE).defaultNamingContext
$link = (Get-GPInheritance -Target $target).GpoLinks | Where-Object { $_.DisplayName -eq $gpo_name } | Select-Object -First 1

if (-not $link) {
    if (-not $check_mode) {
        $link = New-GPLink -Name $gpo_name -Target $target -LinkEnabled Yes -Enforced Yes
    }
    $result.changed = $true
} else {
    if (-not $link.Enabled) {
        if (-not $check_mode) {
            $link = $link | Set-GPLink -LinkEnabled Yes
        }
        $result.changed = $true
    }

    if (-not $link.Enforced) {
        if (-not $check_mode) {
            $null = $link | Set-GPLink -Enforced Yes
        }
        $result.changed = $true
    }
}

Exit-Json -obj $result
