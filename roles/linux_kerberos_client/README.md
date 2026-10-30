# Ansible linux_kerberos_client role

## Overview

Installs Kerberos client packages, configures name resolution for the lab
domain, and writes `/etc/krb5.conf`.

When `dns.mode` is `local_forwarder`, the role configures `dnsmasq` on
`127.0.0.1` to forward queries for the AD domain.

## Variables

### Mandatory variables

* `kerberos.realm`: Kerberos realm to configure.
* `kerberos.kdc_host`: Short hostname of the Key Distribution Center (KDC) or
  domain controller.
* `kerberos.kdc_ip`: IP address of the KDC or domain controller.
* `dns.mode`: DNS behavior for the controller host.

### Variables when `dns.mode` is `local_forwarder`

* `domain.name`: AD DNS domain that `dnsmasq` forwards.
* `dns.upstream_server`: Upstream DNS server for the AD domain.

### Role variables

* `linux_kerberos_client_dnf_packages`: Kerberos and DNS client packages for dnf platforms.
* `linux_kerberos_client_apt_packages`: Kerberos and DNS client packages for apt platforms.

## Example

```yml
- name: configure kerberos on linux hosts
  hosts: linux
  become: true
  roles:
    - linux_kerberos_client
```

## Troubleshooting

If Kerberos works but is slow, check the host resolver path first. The resolver
is the likely cause if any of the following commands is slow, where `DC_FQDN` is
the fully qualified domain name of the domain controller:

* `getent hosts DC_FQDN`
* `kinit USER@REALM`
* `kvno host/DC_FQDN`

A common cause is that the host does not use the local DNS forwarder even though
`dnsmasq` is configured. To check, run:

```sh
cat /etc/resolv.conf
getent hosts domain-con-01.lab.local
dig @127.0.0.1 domain-con-01.lab.local
dig @127.0.0.1 lab.local
```

If the `dig @127.0.0.1` queries are fast but `getent`, `kinit`, or `kvno` are
slow, the host resolver probably points somewhere else.

If another resolver service does not manage `/etc/resolv.conf`, you can fix it
temporarily:

```sh
printf 'nameserver 127.0.0.1\n' | sudo tee /etc/resolv.conf
```

Then retry the commands:

```sh
time getent hosts domain-con-01.lab.local
kdestroy
time kinit vagrant-admin@LAB.LOCAL
time kvno host/domain-con-01.lab.local
```

If the commands become fast immediately, the issue is DNS resolver selection,
not Kerberos.

> [!CAUTION]
> Do not overwrite `/etc/resolv.conf` directly on systems where
> `systemd-resolved`, NetworkManager, `resolvconf`, cloud-init, or another
> resolver manager controls it. Update the active resolver configuration
> through the service instead. A manual `/etc/resolv.conf` edit can also be
> overwritten on reboot or during a network restart, so it is not a persistent
> fix.

### Persistent fix

The persistent fix depends on what manages DNS on the host. To identify the
manager, run:

```sh
# Check whether /etc/resolv.conf is a plain file or a symlink to a managed stub
ls -l /etc/resolv.conf

# Check for common network and DNS managers that may be writing resolver state
ps -ef | grep -E 'dhclient|systemd-networkd|NetworkManager' | grep -v grep

# Check whether systemd-resolved is active on the host
systemctl is-active systemd-resolved
```

Use the results as follows:

* A plain `/etc/resolv.conf` file plus a running `dhclient` process usually
  means DHCP is writing resolver state.
* A symlinked `/etc/resolv.conf` pointing at a `systemd-resolved` stub usually
  means `systemd-resolved` is in control.
* A running NetworkManager service often means DNS should be configured through
  the active NetworkManager connection profile.

Then apply the fix for your resolver manager:

* If the host uses `dhclient`, set the resolver there instead of editing
  `/etc/resolv.conf` directly. For example:

  ```conf
  # /etc/dhcp/dhclient.conf
  prepend domain-name-servers 127.0.0.1;
  ```

  This commonly puts both `127.0.0.1` and the DHCP-provided resolver in
  `/etc/resolv.conf`, with `127.0.0.1` listed first. That is fine as long as the
  local resolver is first and Kerberos and DNS lookups become fast.
* If the host uses `systemd-networkd`, set `DNS=127.0.0.1` in the relevant
  `.network` file and restart `systemd-networkd`.
* If the host uses `resolvconf`, configure the local nameserver through
  `resolvconf`, so the generated resolver state keeps `127.0.0.1`.
* If the host uses NetworkManager, set the connection DNS to `127.0.0.1` in
  NetworkManager instead of replacing `/etc/resolv.conf`.
