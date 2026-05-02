# Ansible windows_adcs role

## Overview

Sets up AD CS on the domain controller for the lab, publishes the workstation
auto-enrollment certificate template, configures the enrollment GPO, and
exports the lab CA chain.

## Variables

### Mandatory Variables

* `domain.name`: The AD DNS domain name.
* `domain.admin.upn`: Domain account used for AD CS and GPO management tasks.
* `domain.admin.password`: Password for `domain.admin.upn`.
* `certificates.autoenroll_template`: Certificate template name to manage and publish.
* `certificates.gpo_name`: GPO name used for machine auto-enrollment.

## Examples

```yml
- name: configure ad cs on the domain controller
  hosts: domain_controller
  gather_facts: false
  roles:
    - windows_adcs
```
