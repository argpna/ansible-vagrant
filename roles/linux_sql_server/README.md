# Ansible linux_sql_server role

## Overview

Installs and configures SQL Server on Linux from the Microsoft package
repositories. This role is the Linux counterpart of the `windows_sql_server`
role. It covers both the `mssql_linux_matrix` hosts (standalone instances for
each distribution and version) and the `mssql_linux_ag` cluster nodes (instances
with high availability and disaster recovery (HADR) enabled for the Pacemaker
cluster).

The role supports the following package managers:

* `apt`: Ubuntu.
* `dnf`: RHEL and Rocky Linux. Rocky Linux 8 uses the raw-command pattern,
  because the dnf Python bindings are unavailable under its python3.9
  interpreter.
* `zypper`: openSUSE Leap, through the SLES repositories. Support is best effort.

The tested distributions and versions are defined in
[`inventory/hosts.d/mssql_linux.yml`](../../inventory/hosts.d/mssql_linux.yml).

## Remove SQL Server

With `-e mssql_engine_state=absent` or `linux_sql_server.state: absent`, the
role stops the service and removes the SQL Server and tool packages,
`/var/opt/mssql`, and the Microsoft package repository file and signing key.

## Variables

All settings live in a single `linux_sql_server` dict, which
[`defaults/main.yml`](defaults/main.yml) defines. Group or host variables that
define the dict replace it entirely, so declare every key.

* `version`: SQL Server major version. Defaults to the `sql_version` inventory
  variable of the host.
* `accept_eula`: Must be `true`. The role forwards it to the package install and
  `mssql-conf setup`.
* `edition`: `MSSQL_PID` value passed to setup. Default: `Developer`.
* `sa_password`: SA password for the unattended setup. Defaults to
  `mssql_sa_password` when it is passed, and to the lab default
  otherwise.
* `enable_agent`: Enable the SQL Server Agent (`sqlagent.enabled`).
* `hadr_enabled`: Enable availability groups (`hadr.hadrenabled`). Set it on the
  `mssql_linux_ag` group.
* `install_tools`: Install `mssql-tools18` and the unixODBC development packages.
* `install_ha_agent`: Install `mssql-server-ha`, which provides the `ocf:mssql:ag`
  Pacemaker resource agent. Set it on the `mssql_linux_ag` group.
* `tcp_port` and `hadr_endpoint_port`: Ports opened in firewalld when
  `manage_firewall` is `true` and firewalld is active.

## Example

```yml
- name: install SQL Server on linux hosts
  hosts: mssql_linux_ag:mssql_linux_matrix
  become: true
  gather_facts: true
  roles:
    - role: linux_sql_server
```
