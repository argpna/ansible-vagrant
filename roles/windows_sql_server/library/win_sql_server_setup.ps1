#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false

$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present"
$media_path = Get-AnsibleParam -obj $params -name "media_path" -type "str" -failifempty $true
$instance_name = Get-AnsibleParam -obj $params -name "instance_name" -type "str" -failifempty $true
$features = Get-AnsibleParam -obj $params -name "features" -type "list" -failifempty $true
$sqlsysadminaccounts = Get-AnsibleParam -obj $params -name "sqlsysadminaccounts" -type "list"
$security_mode = Get-AnsibleParam -obj $params -name "security_mode" -type "str" -default "Windows"
$sa_password = Get-AnsibleParam -obj $params -name "sa_password" -type "str"
$sqlsvc_account = Get-AnsibleParam -obj $params -name "sqlsvc_account" -type "str"
$sqlsvc_password = Get-AnsibleParam -obj $params -name "sqlsvc_password" -type "str"
$agtsvc_account = Get-AnsibleParam -obj $params -name "agtsvc_account" -type "str"
$agtsvc_password = Get-AnsibleParam -obj $params -name "agtsvc_password" -type "str"
$browser_startup_type = Get-AnsibleParam -obj $params -name "browser_startup_type" -type "str" -default "Disabled"
$update_enabled = Get-AnsibleParam -obj $params -name "update_enabled" -type "bool" -default $false
$update_source = Get-AnsibleParam -obj $params -name "update_source" -type "str"
$product_key = Get-AnsibleParam -obj $params -name "product_key" -type "str"
$install_shared_dir = Get-AnsibleParam -obj $params -name "install_shared_dir" -type "str"
$install_shared_wow_dir = Get-AnsibleParam -obj $params -name "install_shared_wow_dir" -type "str"
$instance_dir = Get-AnsibleParam -obj $params -name "instance_dir" -type "str"
$install_sql_data_dir = Get-AnsibleParam -obj $params -name "install_sql_data_dir" -type "str"
$sql_user_db_dir = Get-AnsibleParam -obj $params -name "sql_user_db_dir" -type "str"
$sql_user_db_log_dir = Get-AnsibleParam -obj $params -name "sql_user_db_log_dir" -type "str"
$sql_temp_db_dir = Get-AnsibleParam -obj $params -name "sql_temp_db_dir" -type "str"
$sql_temp_db_log_dir = Get-AnsibleParam -obj $params -name "sql_temp_db_log_dir" -type "str"

$result = @{
    changed = $false
    exists = $false
    instance_name = $instance_name
    reboot_required = $false
    exit_code = $null
    setup_stdout_path = $null
    setup_stderr_path = $null
}

if ($state -ne "present") {
    Fail-Json -obj $result -message "Unsupported state '$state'"
}

if ($security_mode -eq 'SQL' -and -not $sa_password) {
    Fail-Json -obj $result -message "sa_password is required when security_mode=SQL"
}

$instance_names_key = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
$instance_names = $null
if (Test-Path $instance_names_key) {
    $instance_names = Get-ItemProperty -Path $instance_names_key -ErrorAction SilentlyContinue
}

if ($instance_names -and $instance_names.$instance_name) {
    $result.exists = $true
    Exit-Json -obj $result
}

$result.changed = $true
$result.exists = $true

if ($check_mode) {
    Exit-Json -obj $result
}

$setup_exe = Join-Path -Path $media_path -ChildPath 'setup.exe'
if (-not (Test-Path $setup_exe)) {
    Fail-Json -obj $result -message "Could not find setup.exe under $media_path"
}

$setup_args = [System.Collections.Generic.List[string]]::new()
$setup_args.Add('/Q')
$setup_args.Add('/ACTION=Install')
$setup_args.Add('/IACCEPTSQLSERVERLICENSETERMS')
$setup_args.Add('/ENU=True')
$setup_args.Add("/FEATURES=$(@($features) -join ',')")
$setup_args.Add("/INSTANCENAME=$instance_name")
$setup_args.Add("/BROWSERSVCSTARTUPTYPE=$browser_startup_type")
$setup_args.Add("/UPDATEENABLED=$($update_enabled.ToString())")

if ($security_mode -eq 'SQL') {
    $setup_args.Add('/SECURITYMODE=SQL')
}

if ($sqlsysadminaccounts -and $sqlsysadminaccounts.Count -gt 0) {
    $setup_args.Add("/SQLSYSADMINACCOUNTS=`"$(@($sqlsysadminaccounts) -join ' ')`"")
}

if ($security_mode -eq 'SQL' -and $sa_password) {
    $setup_args.Add("/SAPWD=`"$sa_password`"")
}

if ($sqlsvc_account) {
    $setup_args.Add("/SQLSVCACCOUNT=`"$sqlsvc_account`"")
}
if ($sqlsvc_password) {
    $setup_args.Add("/SQLSVCPASSWORD=`"$sqlsvc_password`"")
}
if ($agtsvc_account) {
    $setup_args.Add("/AGTSVCACCOUNT=`"$agtsvc_account`"")
}
if ($agtsvc_password) {
    $setup_args.Add("/AGTSVCPASSWORD=`"$agtsvc_password`"")
}
if ($update_enabled -and $update_source) {
    $setup_args.Add("/UPDATESOURCE=`"$update_source`"")
}
if ($product_key) {
    $setup_args.Add("/PID=`"$product_key`"")
}
if ($install_shared_dir) {
    $setup_args.Add("/INSTALLSHAREDDIR=`"$install_shared_dir`"")
}
if ($install_shared_wow_dir) {
    $setup_args.Add("/INSTALLSHAREDWOWDIR=`"$install_shared_wow_dir`"")
}
if ($instance_dir) {
    $setup_args.Add("/INSTANCEDIR=`"$instance_dir`"")
}
if ($install_sql_data_dir) {
    $setup_args.Add("/INSTALLSQLDATADIR=`"$install_sql_data_dir`"")
}
if ($sql_user_db_dir) {
    $setup_args.Add("/SQLUSERDBDIR=`"$sql_user_db_dir`"")
}
if ($sql_user_db_log_dir) {
    $setup_args.Add("/SQLUSERDBLOGDIR=`"$sql_user_db_log_dir`"")
}
if ($sql_temp_db_dir) {
    $setup_args.Add("/SQLTEMPDBDIR=`"$sql_temp_db_dir`"")
}
if ($sql_temp_db_log_dir) {
    $setup_args.Add("/SQLTEMPDBLOGDIR=`"$sql_temp_db_log_dir`"")
}

$setup_stdout_path = Join-Path -Path $env:TEMP -ChildPath "win_sql_server_setup_$($instance_name)_stdout.log"
$setup_stderr_path = Join-Path -Path $env:TEMP -ChildPath "win_sql_server_setup_$($instance_name)_stderr.log"
$result.setup_stdout_path = $setup_stdout_path
$result.setup_stderr_path = $setup_stderr_path

$process = Start-Process `
    -FilePath $setup_exe `
    -ArgumentList $setup_args `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $setup_stdout_path `
    -RedirectStandardError $setup_stderr_path
$result.exit_code = [int]$process.ExitCode

if ($process.ExitCode -eq 3010) {
    $result.reboot_required = $true
}
elseif ($process.ExitCode -ne 0) {
    Fail-Json -obj $result -message "SQL Server setup.exe failed with exit code $($process.ExitCode)"
}

Exit-Json -obj $result
