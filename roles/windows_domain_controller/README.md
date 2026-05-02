# Ansible windows_domain_controller role

## Overview

Promotes a Windows host to a domain controller, points the chosen adapter at
localhost for DNS, creates the initial domain admin account, and validates that
account.

## Variables

### Mandatory Variables

* `windows_connection_adapter_name`: The Windows adapter used for domain traffic.
* `domain.name`: The AD DNS domain name to create.
* `domain.safe_mode_password`: The safe mode password for DC promotion.
* `domain.admin.username`: The initial domain admin account name.
* `domain.admin.password`: The initial domain admin account password.
* `domain.admin.upn`: The UPN used to validate the created account.

## Examples

```yml
- name: promote the domain controller
  hosts: domain_controller
  gather_facts: false
  pre_tasks:
    - ansible.builtin.include_role:
        name: windows_common
        tasks_from: find_connection_adapter.yml
  roles:
    - windows_domain_controller
```
