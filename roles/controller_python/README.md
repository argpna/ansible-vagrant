# Ansible controller_python role

## Overview

Ensures the controller has a supported Python runtime and creates the
controller virtualenv with the configured Python line.

## Variables

### Mandatory Variables

* `controller.python.source_version`: Full CPython release to build, for example `3.11.1`.
* `controller.python.venv_path`: Path to the controller virtualenv.
* `controller.admin_user.name`: Owner for the virtualenv parent directory.
* `controller.admin_user.group`: Group for the virtualenv parent directory.

## Examples

```yml
- name: prepare python on the controller
  hosts: control_node
  roles:
    - controller_python
```
