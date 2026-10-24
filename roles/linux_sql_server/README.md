# Ansible linux_sql_server role

## Overview

Installs and configures SQL Server on Linux from the Microsoft package
repositories. This is the Linux counterpart of `windows_sql_server` role and
covers both the `mssql_linux_matrix` hosts (standalone instances per distro/version)
and the `mssql_linux_ag` cluster nodes (HADR-enabled instances for the
Pacemaker cluster).

Supported package managers:

* `apt` - Ubuntu 20.04/22.04/24.04
* `dnf` - RHEL/Rocky 8 and 9 (Rocky 8 uses the raw-command pattern because the
  dnf python bindings are unavailable under the python3.9 interpreter)
* `zypper` - openSUSE Leap 15 via the SLES 15 repos (best effort)

## Variables

All settings live in a single `linux_sql_server` dict (see
`defaults/main.yml`). Group or host vars that define the dict replace it
entirely, so declare every key.

* `version`: SQL Server major version (`2019`, `2022`, `2025`). Defaults to the
  host's `sql_version` inventory var.
* `accept_eula`: Must be `true`; forwarded to the package install and
  `mssql-conf setup`.
* `edition`: `MSSQL_PID` value passed to setup (default `Developer`).
* `sa_password`: SA password used for the unattended setup.
* `enable_agent`: Enable the SQL Server Agent (`sqlagent.enabled`).
* `hadr_enabled`: Enable availability groups (`hadr.hadrenabled`). Set on the
  `mssql_linux_ag` group.
* `install_tools`: Install `mssql-tools18` + unixODBC development packages.
* `install_ha_agent`: Install `mssql-server-ha` (the `ocf:mssql:ag` Pacemaker
  resource agent). Set on the `mssql_linux_ag` group.
* `tcp_port` / `hadr_endpoint_port`: Ports opened in firewalld when
  `manage_firewall` is true and firewalld is active.

## Examples

```yml
- name: install SQL Server on linux hosts
  hosts: mssql_linux_ag:mssql_linux_matrix
  become: true
  gather_facts: true
  roles:
    - role: linux_sql_server
```
