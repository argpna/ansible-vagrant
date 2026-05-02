# Ansible windows_failover_cluster role

## Overview

Prepares and manages a Windows Server Failover Cluster for the lab SQL Server
hosts. The role is split into operation-specific entry points and is normally
called with `tasks_from` from
[windows-failover-cluster.yml](/home/arun/projects/mssql-infra/playbooks/windows-failover-cluster.yml).

## Variables

### Mandatory Variables

* `domain.name`: AD DNS domain name for the cluster nodes.
* `mssql.cluster.name`: Windows failover cluster name.
* `mssql.cluster.dns_name`: DNS name registered for the cluster.
* `mssql.cluster.witness.type`: Witness type. The current path expects `file_share`.
* `mssql.cluster.witness.host`: Inventory host that owns the witness share.
* `mssql.cluster.witness.path`: UNC path used as the file share witness.

## Entry Points

* `prereqs.yml`: Install and validate failover clustering prerequisites on the cluster nodes.
* `file_share_witness.yml`: Create or remove the witness directory and SMB share.
* `create_cluster.yml`: Create the cluster and attach the configured witness.
* `destroy_cluster.yml`: Remove the cluster and detach the witness.

## Examples

```yml
- name: create the failover cluster
  hosts: mssql_windows_ag[0]
  gather_facts: false
  tasks:
    - ansible.builtin.include_role:
        name: windows_failover_cluster
        tasks_from: create_cluster.yml

- name: remove the failover cluster
  hosts: mssql_windows_ag[0]
  gather_facts: false
  tasks:
    - ansible.builtin.include_role:
        name: windows_failover_cluster
        tasks_from: destroy_cluster.yml
```
