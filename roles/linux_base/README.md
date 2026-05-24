# Ansible linux_base role

## Overview

Installs baseline Linux packages and creates the controller admin account with
its SSH key and passwordless sudo access.

## Variables

### Mandatory Variables

* `controller.admin_user.name`: The Linux admin user name.
* `controller.admin_user.group`: The Linux admin group name.
* `controller.admin_user.password_hash`: The hashed password for the admin user.
* `controller.admin_user.authorized_key`: The SSH public key to add for the admin user.

### Role Variables

* `linux_base_packages`: Baseline package list for both apt and dnf platforms.

## Examples

```yml
- name: prepare the controller host
  hosts: control_node
  become: true
  roles:
    - linux_base
```
