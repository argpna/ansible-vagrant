# Ansible controller_python role

## Overview

Installs the configured CPython release from source and creates the controller
virtualenv with it.

## Variables

### Mandatory variables

* `controller.python.source_version`: Full CPython release to build, for example `3.11.1`.
* `controller.python.venv_path`: Path to the controller virtualenv.
* `controller.admin_user.name`: Owner of the virtualenv parent directory.
* `controller.admin_user.group`: Group of the virtualenv parent directory.

### Role variables

* `controller_python_redhat_build_packages`: Build dependency packages for RedHat-family hosts.

## Example

```yml
- name: prepare python on the controller
  hosts: control_node
  roles:
    - controller_python
```
