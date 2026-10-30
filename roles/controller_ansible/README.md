# Ansible controller_ansible role

## Overview

Installs Ansible and the required Windows automation Python packages into the
controller virtualenv. It also installs an `enter-ansible-env` helper that
activates the virtualenv.

The role requires the controller Python runtime and virtualenv to exist, which
the `controller_python` role creates.

## Variables

### Mandatory variables

* `controller.python.venv_path`: Path to the controller virtualenv.
* `controller.ansible.package_spec`: Ansible package spec to install into the virtualenv.
* `controller.ansible.python_packages`: Additional Python packages to install alongside Ansible.

## Example

```yml
- name: install ansible on the controller
  hosts: control_node
  roles:
    - controller_ansible
```
