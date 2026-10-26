# Ansible windows_sql_server role

## Overview

Installs SQL Server on Windows hosts by driving Microsoft `setup.exe` through
repo-local modules. The role first sets up optional SQL service accounts, then
runs the SQL Server install tasks.

## Variables

Configuration lives under the `windows_sql_server` variable namespace.

### Mandatory Variables

* `windows_sql_server.media_path` or `windows_sql_server.media_iso_path`: Directory with
  the SQL Server setup media, or an ISO image.

### Optional Variables

* `windows_sql_server.state`: Install state. Default: `present`
* `windows_sql_server.instance_name`: SQL instance name. Default: `MSSQLSERVER`
* `windows_sql_server.features`: Setup features to install. Default:
  `['SQLEngine']`
* `windows_sql_server.sqlsysadminaccounts`: Sysadmin accounts passed to setup
* `windows_sql_server.security_mode`: `Windows` or SQL authentication mode
* `windows_sql_server.sa_password`: SA password when SQL authentication is used
* `windows_sql_server.product_key`: Product key when required
* `windows_sql_server.update_enabled`: Whether setup should enable updates
* `windows_sql_server.update_source`: Update source for setup
* `windows_sql_server.reboot_if_required`: Reboot when setup requires it
* `windows_sql_server.manage_firewall`: Add an inbound firewall rule for
  `windows_sql_server.tcp_port` (default `1433`). Default: `false`

### Service Accounts

* `windows_sql_server.service_accounts.manage`: Create SQL service accounts
  before install. When `false`, setup uses its built-in service accounts.
* `windows_sql_server.service_accounts.sqlsvc`: Database Engine service account
* `windows_sql_server.service_accounts.agtsvc`: SQL Server Agent service account

When service account management is enabled, the role creates the domain users
first and then feeds those identities into SQL Server setup.

## Removing SQL Server (Engine only)

With `-e mssql_engine_state=absent` (or `windows_sql_server.state: absent`) the role mounts
`windows_sql_server.media_iso_path`, runs the setup uninstall for the configured features and
instance, removes the firewall rule, and finally reboots the server if/when a pending-restart
flag is set in the windows registry.

## Example

```yml
- name: install SQL Server on Windows hosts
  hosts: mssql_windows_ag
  gather_facts: false
  roles:
    - role: windows_sql_server
```
