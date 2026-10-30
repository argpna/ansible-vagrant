# Ansible windows_domain_member role

## Overview

Points the selected network adapter at the domain controller for DNS, joins the
host to the domain, reboots if required, and validates domain logon.

## Variables

### Mandatory variables

* `windows_common_connection_adapter_name`: Windows adapter used to reach the domain controller.
* `domain.controller_ip`: IP address of the domain controller.
* `domain.name`: AD DNS domain to join.
* `domain.admin.upn`: Domain account that can join hosts to the domain.
* `domain.admin.password`: Password for `domain.admin.upn`.

## Example

```yml
- name: join windows members to the domain
  hosts: domain_members
  gather_facts: false
  pre_tasks:
    - ansible.builtin.include_role:
        name: windows_common
        tasks_from: find_connection_adapter.yml
  roles:
    - windows_domain_member
```
