# Ansible linux_pacemaker_cluster role

## Overview

Prepares and manages the Pacemaker/Corosync cluster for the lab Linux SQL
Server hosts. This is the Linux counterpart of `windows_failover_cluster`
(`cluster_type: external` availability groups use Pacemaker instead of WSFC).
The role is split into operation-specific entry points and is normally called
with `tasks_from` from
[linux-pacemaker-cluster.yml](../../playbooks/linux-pacemaker-cluster.yml).

The role leaves a running, empty cluster plus the SQL login the
`ocf:mssql:ag` resource agent authenticates with. Availability groups and the
Pacemaker AG/VIP resources are not created here.

## Variables

### Mandatory Variables

* `mssql.cluster.name`: Pacemaker/Corosync cluster name.
* `mssql.cluster.hacluster_password`: Plaintext `hacluster` password used by `pcs host auth`.
* `mssql.cluster.hacluster_password_hash`: sha512-crypt hash of the same password, set on the `hacluster` user.
* `mssql.topology.nodes`: Inventory hostnames of the cluster nodes (at least two).

### sql_login.yml Variables

* `mssql.cluster.sql_login.name` / `.password`: SQL login for the Pacemaker resource agent.
* `mssql.cluster.sql_login.secrets_file`: Credentials file the agent reads (normally `/var/opt/mssql/secrets/passwd`).
* `linux_sql_server.sa_password`: Used to connect and create the login.

### Role Defaults

* `linux_pacemaker_cluster_properties`: Pacemaker properties applied after creation.
  `stonith-enabled=false` is lab-only - production clusters need fencing.
* `linux_pacemaker_cluster_totem_token_ms`: Corosync totem token timeout (set to 30000).

## Entry Points

* `prereqs.yml`: Install pacemaker/corosync/pcs, resolve node hostnames, set the
  `hacluster` password, start pcsd, open firewalld, and clear any
  distribution-default corosync config.
* `create_cluster.yml`: Authenticate pcsd, create/start/enable the cluster from
  the bootstrap node, and apply the totem timeout and cluster properties.
* `destroy_cluster.yml`: Destroy the cluster on all nodes.
* `sql_login.yml`: Create or remove the resource-agent SQL login and its
  secrets file (controlled by `linux_pacemaker_cluster_sql_login_state`).

## Examples

```yml
- name: create the pacemaker cluster
  hosts: mssql_linux_ag[0]
  become: true
  gather_facts: false
  tasks:
    - ansible.builtin.include_role:
        name: linux_pacemaker_cluster
        tasks_from: create_cluster.yml

- name: remove the pacemaker cluster
  hosts: mssql_linux_ag[0]
  become: true
  gather_facts: false
  tasks:
    - ansible.builtin.include_role:
        name: linux_pacemaker_cluster
        tasks_from: destroy_cluster.yml
```
