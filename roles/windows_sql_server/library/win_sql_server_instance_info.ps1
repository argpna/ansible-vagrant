#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true
$instance_name = Get-AnsibleParam -obj $params -name "instance_name" -type "str" -failifempty $true

$result = @{
    changed = $false
    exists = $false
    instance_name = $instance_name
    instance_id = ""
    service_name = ""
}

$instance_names_key = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'

if (-not (Test-Path $instance_names_key)) {
    Exit-Json -obj $result
}

$instance_names = Get-ItemProperty -Path $instance_names_key -ErrorAction SilentlyContinue
if (-not $instance_names) {
    Exit-Json -obj $result
}

$instance_id = $instance_names.$instance_name
if (-not $instance_id) {
    Exit-Json -obj $result
}

$service_name = if ($instance_name -eq 'MSSQLSERVER') {
    'MSSQLSERVER'
}
else {
    "MSSQL`$$instance_name"
}

$result.exists = $true
$result.instance_id = [string]$instance_id
$result.service_name = $service_name

Exit-Json -obj $result
