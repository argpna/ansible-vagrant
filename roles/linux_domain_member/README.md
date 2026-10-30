# Ansible linux_domain_member role

## Overview

Joins a Linux host to the lab Active Directory domain. The role installs the
realmd, sssd, adcli, and related packages for the host package manager. It
points systemd-resolved at the domain controller for the lab domain, so Active
Directory SRV record discovery and short-name resolution work. It then creates
the host's A record in the AD DNS zone, joins the realm with the domain admin
account, and validates the join by resolving the admin identity through sssd.

Run the `linux_kerberos_client` role first. It writes `/etc/krb5.conf` and
installs the Kerberos client packages that the realm join depends on.
[`linux-domain-members.yml`](../../playbooks/linux-domain-members.yml) runs both
roles in order.

On hosts without systemd-resolved, name resolution relies on the dnsmasq
forwarder that `linux_kerberos_client` configures.

## Variables

### Mandatory variables

* `domain.name`: AD DNS domain to join.
* `domain.controller_host`: Inventory host name of the domain controller, used
  as the `delegate_to` target for creating the host's DNS A record.
* `domain.controller_ip`: IP address of the domain controller.
* `domain.admin.username`: `sAMAccountName` of the domain admin, used to
  validate the realm join with `id`.
* `domain.admin.upn`: User principal name (UPN) of the domain admin, used for
  `realm join`.
* `domain.admin.password`: Password for `domain.admin.upn`.

### Role variables

* `linux_domain_member_dnf_packages`: realmd and sssd packages for dnf platforms.
* `linux_domain_member_apt_packages`: realmd and sssd packages for apt platforms.
* `linux_domain_member_resolved_dropin`: Path to the systemd-resolved drop-in
  that routes lab domain queries to the domain controller.

## Example

```yml
- name: join MSSQL Linux cluster hosts to the lab domain
  hosts: mssql_linux_ag
  become: true
  gather_facts: true
  roles:
    - role: linux_kerberos_client
    - role: linux_domain_member
```
