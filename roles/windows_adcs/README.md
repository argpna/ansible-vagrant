# Ansible windows_adcs role

## Overview

Sets up Active Directory Certificate Services (AD CS) on the domain controller,
publishes the workstation auto-enrollment certificate template, configures the
enrollment Group Policy Object (GPO), and exports the lab certificate authority
(CA) chain.

## Variables

### Mandatory variables

* `domain.name`: AD DNS domain name.
* `domain.admin.upn`: Domain account for AD CS and GPO management tasks.
* `domain.admin.password`: Password for `domain.admin.upn`.
* `certificates.autoenroll_template`: Certificate template to manage and publish.
* `certificates.gpo_name`: GPO used for machine auto-enrollment.

## Example

```yml
- name: configure ad cs on the domain controller
  hosts: domain_controller
  gather_facts: false
  roles:
    - windows_adcs
```
