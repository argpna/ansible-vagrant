# Ansible windows_sql_server role

## Overview

Installs SQL Server on Windows hosts by driving Microsoft `setup.exe` through
modules in this repository. The role first sets up optional SQL service
accounts, then runs the SQL Server install tasks.

## Variables

Configuration lives under the `windows_sql_server` variable namespace.

### Mandatory variables

* `windows_sql_server.media_path` or `windows_sql_server.media_iso_path`:
  Directory with the SQL Server setup media, or an ISO image.

### Optional variables

* `windows_sql_server.state`: Install state. Default: `present`.
* `windows_sql_server.instance_name`: SQL instance name. Default: `MSSQLSERVER`.
* `windows_sql_server.features`: Setup features to install. Default:
  `['SQLEngine']`.
* `windows_sql_server.sqlsysadminaccounts`: Sysadmin accounts passed to setup.
* `windows_sql_server.security_mode`: Authentication mode, either `Windows` or
  SQL authentication.
* `windows_sql_server.sa_password`: SA password when SQL authentication is used.
* `windows_sql_server.product_key`: Product key, when required.
* `windows_sql_server.update_enabled`: Whether setup enables updates.
* `windows_sql_server.update_source`: Update source for setup.
* `windows_sql_server.reboot_if_required`: Reboot when setup requires it.
* `windows_sql_server.manage_firewall`: Add an inbound firewall rule for
  `windows_sql_server.tcp_port`, which defaults to `1433`. Default: `false`.

### Service accounts

* `windows_sql_server.service_accounts.manage`: Create SQL service accounts
  before install. When `false`, setup uses its built-in service accounts.
* `windows_sql_server.service_accounts.sqlsvc`: Database Engine service account.
* `windows_sql_server.service_accounts.agtsvc`: SQL Server Agent service account.

When service account management is enabled, the role creates the domain users
first and then passes those identities to SQL Server setup.

## Remove SQL Server

With `-e mssql_engine_state=absent` or `windows_sql_server.state: absent`, the
role mounts `windows_sql_server.media_iso_path` and runs the setup uninstall for
the configured features and instance. It then removes the firewall rule and
reboots the server if a pending-restart flag is set in the Windows registry.

## Example

```yml
- name: install SQL Server on Windows hosts
  hosts: mssql_windows_ag
  gather_facts: false
  roles:
    - role: windows_sql_server
```
