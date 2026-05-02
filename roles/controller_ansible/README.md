# Ansible controller_ansible role

## Overview

Installs Ansible and the required Windows automation Python packages into the
controller virtualenv. It also installs a small `enter-ansible-env` helper that
activates that environment.

The role expects the controller Python runtime and virtualenv to already exist,
typically via `controller_python`.

## Variables

### Mandatory Variables

* `controller.python.venv_path`: Path to the controller virtualenv.
* `controller.ansible.package_spec`: The Ansible package spec to install into the virtualenv.
* `controller.ansible.python_packages`: Additional Python packages to install alongside Ansible.

## Examples

```yml
- name: install ansible on the controller
  hosts: control_node
  roles:
    - controller_ansible
```
