# Ansible linux_domain_member role

## Overview

Joins a Linux host to the lab Active Directory domain. Installs
realmd/sssd/adcli (and friends) for the host package manager, points
systemd-resolved at the domain controller for the lab domain (so AD SRV
discovery and short-name resolution work), creates the host's A record in the
AD DNS zone, joins the realm with the domain admin account, and validates the
join by resolving the admin identity through sssd.

Run `linux_kerberos_client` role first - it writes `/etc/krb5.conf` and the
Kerberos client packages this role's realm join depends on.
`playbooks/linux-domain-members.yml` runs both roles in the correct order.

On hosts without systemd-resolved, name resolution instead relies on the
dnsmasq forwarder configured by `linux_kerberos_client`.

## Variables

### Mandatory Variables

* `domain.name`: The AD DNS domain to join.
* `domain.controller_host`: Inventory host name of the domain controller, used
  as the `delegate_to` target for creating the host's DNS A record.
* `domain.controller_ip`: The IP address of the domain controller.
* `domain.admin.username`: The domain admin's sAMAccountName, used to validate
  the realm join via `id`.
* `domain.admin.upn`: The domain admin's UPN, used for `realm join`.
* `domain.admin.password`: The password for `domain.admin.upn`.

### Role Variables

* `linux_domain_member_dnf_packages`: realmd/sssd packages for dnf platforms.
* `linux_domain_member_apt_packages`: realmd/sssd packages for apt platforms.
* `linux_domain_member_resolved_dropin`: Path to the systemd-resolved drop-in
  that routes lab domain queries to the domain controller.

## Examples

```yml
- name: join MSSQL Linux cluster hosts to the lab domain
  hosts: mssql_linux_ag
  become: true
  gather_facts: true
  roles:
    - role: linux_kerberos_client
    - role: linux_domain_member
```
