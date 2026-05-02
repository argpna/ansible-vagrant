# Ansible windows_winrm_cert role

## Overview

Configures the WinRM HTTPS listener to use an AD CS-issued machine
certificate. In this repo, the associated CA chain is exported to
`ca_chain.pem` in the repo root so controller-side PSRP can validate the
listener certificate after bootstrap. The intended validated path is:

* the listener certificate SAN contains the host FQDN
* the controller trusts the exported lab CA chain
* PSRP connects to the host FQDN when the CA chain is available locally

Certificate selection prefers the local machine certificate whose SAN contains
`<inventory_hostname>.<domain.name>`. When the AD CS role has already exported
the CA subject from the domain controller in the same playbook run, that
issuer is used as an additional filter.

## Variables

### Mandatory Variables

* `domain.name`: The AD DNS domain name.
* `domain.controller_host`: Inventory name of the domain controller host.
* `windows_is_domain_controller`: Whether certificate selection should use the domain-controller-specific checks.

## Examples

```yml
- name: update winrm listener certificates on member hosts
  hosts: domain_members
  gather_facts: false
  roles:
    - role: windows_winrm_cert
      vars:
        windows_is_domain_controller: false
```
