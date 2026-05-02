# Ansible linux_kerberos_client role

## Overview

Installs Kerberos client packages, configures name resolution for the lab
domain, and writes `/etc/krb5.conf`.

When `dns.mode` is `local_forwarder`, the role configures `dnsmasq` on
`127.0.0.1` for AD-domain forwarding.

## Variables

### Mandatory Variables

* `kerberos.realm`: The Kerberos realm to configure.
* `kerberos.kdc_host`: The short hostname of the KDC or domain controller.
* `kerberos.kdc_ip`: The IP address of the KDC or domain controller.
* `dns.mode`: DNS behavior for the controller host.

### Additional Variables Used When `dns.mode == 'local_forwarder'`

* `domain.name`: The AD DNS domain forwarded by `dnsmasq`.
* `dns.upstream_server`: The upstream DNS server for the AD domain.

## Examples

```yml
- name: configure kerberos on linux hosts
  hosts: linux
  become: true
  roles:
    - linux_kerberos_client
```

## Troubleshooting

If Kerberos works but is unexpectedly slow, check the host resolver path first.
For instance if the following is slow

* `getent hosts <dc fqdn>`
* `kinit user@REALM`
* `kvno host/<dc fqdn>`

One common cause in this repo is that the host is not actually using the
local DNS forwarder even though `dnsmasq` is configured.

Quick checks:

```sh
cat /etc/resolv.conf
getent hosts domain-con-01.lab.local
dig @127.0.0.1 domain-con-01.lab.local
dig @127.0.0.1 lab.local
```

If `dig @127.0.0.1 ...` is fast but `getent`, `kinit`, or `kvno` are slow,
the host resolver is probably still pointing somewhere else.

General temporary fix when `/etc/resolv.conf` is not managed by another
resolver service:

```sh
printf 'nameserver 127.0.0.1\n' | sudo tee /etc/resolv.conf
```

After that, retry:

```sh
time getent hosts domain-con-01.lab.local
kdestroy
time kinit vagrant-admin@LAB.LOCAL
time kvno host/domain-con-01.lab.local
```

If those become fast immediately, the issue is DNS resolver selection rather
than Kerberos itself.

> [!CAUTION]
> Do not overwrite `/etc/resolv.conf` blindly on systems where it is managed by
> `systemd-resolved`, NetworkManager, `resolvconf`, cloud-init, or another
> resolver manager. In those cases, update the active resolver configuration
> through the appropriate service instead of replacing the file directly. A
> manual `/etc/resolv.conf` edit may also be overwritten on reboot or during a
> network restart, so do not treat it as a persistent fix.

Persistent fix options depend on what manages DNS on the host:

Quick ways to identify that:

```sh
# Check whether /etc/resolv.conf is a plain file or a symlink to a managed stub
ls -l /etc/resolv.conf

# Check for common network/DNS managers that may be writing resolver state
ps -ef | grep -E 'dhclient|systemd-networkd|NetworkManager' | grep -v grep

# Check whether systemd-resolved is active on the host
systemctl is-active systemd-resolved
```

General hints:

* A plain `/etc/resolv.conf` file plus a running `dhclient` process usually
  means DHCP is writing resolver state.
* A symlinked `/etc/resolv.conf` pointing at a `systemd-resolved` stub usually
  means `systemd-resolved` is in control.
* A running NetworkManager service often means DNS should be configured through
  the active NetworkManager connection profile.

* If the host uses `dhclient`, set the resolver there instead of editing
  `/etc/resolv.conf` directly. For example:

```conf
# /etc/dhcp/dhclient.conf
prepend domain-name-servers 127.0.0.1;
```

This commonly results in both `127.0.0.1` and the DHCP-provided resolver being
present in `/etc/resolv.conf`, with `127.0.0.1` listed first. That is fine as
long as the local resolver is first and Kerberos/DNS lookups become fast.

* If the host uses `systemd-networkd`, set `DNS=127.0.0.1` in the relevant
  `.network` file and restart `systemd-networkd`.
* If the host uses `resolvconf`, configure the local nameserver through
  `resolvconf` so generated resolver state keeps `127.0.0.1`.
* If the host uses NetworkManager, configure the connection DNS to
  `127.0.0.1` in NetworkManager instead of replacing `/etc/resolv.conf`.
