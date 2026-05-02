# Ansible windows_common role

## Overview

Provides shared helper tasks for Windows playbooks. The role includes local
Windows modules for resolving the connection adapter name from `ansible_host`,
keeping DNS registration enabled only on that adapter, and removing unexpected
A records for the current hostname from the AD DNS zone while keeping the
intended lab IP.

## Role Modules

* `win_connection_adapter_info`: Finds enabled adapters assigned to an IP
  address.
* `win_dns_registration`: Enables DNS registration on the selected adapter and
  disables it on other non-loopback DNS client interfaces.
* `win_dns_host_record_cleanup`: Removes A records that do not match the
  expected host IP.

## Variables

### Mandatory Variables

* `ansible_host`: The host IP address used to identify the connection adapter.
* `windows_connection_adapter_name`: Required by the DNS-registration helper after
  the connection adapter has been resolved.
* `domain.name`: Required by the DNS cleanup helper.
* `domain.admin.upn`: Required by the DNS cleanup helper.
* `domain.admin.password`: Required by the DNS cleanup helper.

## Examples

```yml
- name: resolve the connection adapter
  hosts: windows
  gather_facts: false
  tasks:
    - name: find the adapter
      ansible.builtin.include_role:
        name: windows_common
        tasks_from: find_connection_adapter.yml

    - name: keep DNS registration only on the connection adapter
      ansible.builtin.include_role:
        name: windows_common
        tasks_from: configure_dns_registration.yml

    - name: remove unexpected DNS A records for the current hostname
      ansible.builtin.include_role:
        name: windows_common
        tasks_from: cleanup_host_dns_records.yml
```
