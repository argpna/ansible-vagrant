# Ansible windows_openssh role

## Overview

Installs the Windows OpenSSH Server capability, ensures the service is running,
opens the firewall rule, and configures the default shell.

## Variables

All variables are optional.

### Optional Variables

* `windows_extras.openssh.service_state`: Desired `sshd` service state.
* `windows_extras.openssh.firewall_port`: Firewall port for OpenSSH.
* `windows_extras.openssh.default_shell`: Default shell launched by SSH sessions.

## Examples

```yml
- name: install windows openssh
  hosts: windows
  gather_facts: false
  become: true
  become_method: runas
  become_user: SYSTEM
  roles:
    - windows_openssh
```
