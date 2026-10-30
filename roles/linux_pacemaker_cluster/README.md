# Ansible linux_pacemaker_cluster role

## Overview

Prepares and manages the Pacemaker and Corosync cluster for the lab Linux SQL
Server hosts. This role is the Linux counterpart of `windows_failover_cluster`.
Availability groups with `cluster_type: external` use Pacemaker instead of
Windows Server Failover Clustering (WSFC).

The role is split into operation-specific entry points.
[`linux-pacemaker-cluster.yml`](../../playbooks/linux-pacemaker-cluster.yml)
normally calls them with `tasks_from`.

The role leaves a running, empty cluster plus the SQL login that the
`ocf:mssql:ag` resource agent authenticates with. Availability groups and the
Pacemaker availability group and virtual IP resources are created outside this
role.

## Variables

### Mandatory variables

* `mssql.cluster.name`: Pacemaker and Corosync cluster name.
* `mssql.cluster.hacluster_password`: Plaintext `hacluster` password used by `pcs host auth`.
* `mssql.cluster.hacluster_password_hash`: sha512-crypt hash of the same password, set on the `hacluster` user.
* `mssql.topology.nodes`: Inventory hostnames of the cluster nodes. A cluster needs at least two.

### Variables for `sql_login.yml`

* `mssql.cluster.sql_login.name` and `mssql.cluster.sql_login.password`: SQL login for the Pacemaker resource agent.
* `mssql.cluster.sql_login.secrets_file`: Credentials file that the agent reads, normally `/var/opt/mssql/secrets/passwd`.
* `linux_sql_server.sa_password`: Password used to connect and create the login.

### Role defaults

* `linux_pacemaker_cluster_properties`: Pacemaker properties applied after creation.
  The default sets `stonith-enabled=false`, which suits a lab only. Production
  clusters need fencing.
* `linux_pacemaker_cluster_totem_token_ms`: Corosync totem token timeout in milliseconds.

## Entry points

* `prereqs.yml`: Install Pacemaker, Corosync, and pcs, resolve node hostnames,
  set the `hacluster` password, start pcsd, open firewalld, and clear any
  distribution-default Corosync configuration.
* `create_cluster.yml`: Authenticate pcsd, create, start, and enable the cluster
  from the bootstrap node, and apply the totem timeout and cluster properties.
* `destroy_cluster.yml`: Destroy the cluster on all nodes.
* `sql_login.yml`: Create or remove the resource-agent SQL login and its secrets
  file, as set by `linux_pacemaker_cluster_sql_login_state`.

## Example

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
