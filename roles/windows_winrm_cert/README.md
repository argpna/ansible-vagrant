# Ansible windows_winrm_cert role

## Overview

Configures the WinRM HTTPS listener to use a machine certificate issued by
Active Directory Certificate Services (AD CS). In this repository, the role
exports the associated certificate authority (CA) chain to `ca_chain.pem` in the
repository root, so controller-side PowerShell Remoting Protocol (PSRP) can
validate the listener certificate after bootstrap. PSRP validates the listener
certificate when:

* The listener certificate Subject Alternative Name (SAN) contains the host
  fully qualified domain name (FQDN).
* The controller trusts the exported lab CA chain.
* PSRP connects to the host FQDN and the CA chain is available locally.

Certificate selection prefers the local machine certificate whose SAN contains
`<inventory_hostname>.<domain.name>`. When the AD CS role has already exported
the CA subject from the domain controller in the same playbook run, the role
uses the issuer as an additional filter.

## Variables

### Mandatory variables

* `domain.name`: AD DNS domain name.
* `domain.controller_host`: Inventory name of the domain controller host.
* `windows_winrm_cert_is_domain_controller`: Whether certificate selection uses
  the domain-controller-specific checks.

## Example

```yml
- name: update winrm listener certificates on member hosts
  hosts: domain_members
  gather_facts: false
  roles:
    - role: windows_winrm_cert
      vars:
        windows_winrm_cert_is_domain_controller: false
```
