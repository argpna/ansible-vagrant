# Ansible linux_base role

## Overview

Installs baseline Linux packages and creates the controller admin account with
its SSH key and passwordless sudo access.

## Variables

### Mandatory variables

* `controller.admin_user.name`: Linux admin user name.
* `controller.admin_user.group`: Linux admin group name.
* `controller.admin_user.password_hash`: Hashed password for the admin user.
* `controller.admin_user.authorized_key`: SSH public key to add for the admin user.

### Role variables

* `linux_base_packages`: Baseline packages for both apt and dnf platforms.

## Example

```yml
- name: prepare the controller host
  hosts: control_node
  become: true
  roles:
    - linux_base
```
