# Ansible windows_openssh role

## Overview

Installs the Windows OpenSSH Server capability, sets the service to the desired
state, opens the firewall rule, and configures the default shell.

## Variables

All variables are optional.

### Optional variables

* `windows_extras.openssh.service_state`: Desired `sshd` service state.
* `windows_extras.openssh.firewall_port`: Firewall port for OpenSSH.
* `windows_extras.openssh.default_shell`: Default shell for SSH sessions.

## Example

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
