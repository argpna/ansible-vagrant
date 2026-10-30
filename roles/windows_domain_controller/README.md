# Ansible windows_domain_controller role

## Overview

Promotes a Windows host to a domain controller, points the chosen adapter at
localhost for DNS, creates the initial domain admin account, and validates that
account.

## Variables

### Mandatory variables

* `windows_common_connection_adapter_name`: Windows adapter used for domain traffic.
* `domain.name`: AD DNS domain name to create.
* `domain.safe_mode_password`: Safe mode password for the domain controller promotion.
* `domain.admin.username`: Initial domain admin account name.
* `domain.admin.password`: Initial domain admin account password.
* `domain.admin.upn`: User principal name (UPN) used to validate the created account.

## Example

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
