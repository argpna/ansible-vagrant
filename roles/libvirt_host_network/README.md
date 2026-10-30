# Ansible libvirt_host_network role

## Overview

Manages libvirt lab networks on the host. The role resolves the active
network inventory, defines or removes the configured libvirt networks, and
manages firewalld and scoped outbound network address translation (NAT) for
those networks.

## Variables

### Mandatory variables

* `networks`: Network definitions keyed by network name.

### Optional variables

* `libvirt_host_network_state`: `present`, `absent`, or `purged`.
* `libvirt_host_network_redefine`: Replace an existing network definition when
  it does not match the generated XML.
* `libvirt_host_network_generate_xml`: Generate network XML from inventory and
  sync DHCP reservations. Defaults to `true` when `networks` is defined.
* `libvirt_host_network_manage_firewalld`: Manage the libvirt firewalld zone.
* `libvirt_host_network_outbound_nat`: Manage scoped outbound NAT with
  nftables.
* `libvirt_host_network_firewalld_install`: Install firewalld if needed.
* `libvirt_host_network_firewalld_start`: Start firewalld if installed.

## Firewalld

Firewalld might not be installed. This is common on apt-based hosts, where
firewalld is usually not the default firewall service.

A topology can enable firewalld management to disable broad libvirt-zone
masquerade before Windows Server Failover Clustering (WSFC) and availability
group traffic is tested.

Firewalld management behaves as follows:

* If `firewall-cmd` exists and firewalld is running, the role manages the
  configured zone.
* If firewalld is missing or stopped, the role skips firewalld changes.
* When enabled, outbound NAT is managed separately with nftables.

To have the role install firewalld through the host package manager, set:

```yml
libvirt_host_network_firewalld_install: true
libvirt_host_network_firewalld_start: true
```

The package and service names default to `firewalld`, which works for both
apt-based and dnf-based distributions:

```yml
libvirt_host_network_firewalld_package: firewalld
libvirt_host_network_firewalld_service: firewalld
```

To fail when firewalld is unavailable on a host that requires it, set
`libvirt_host_network_firewalld_fail_if_unavailable: true`.

The zone change uses the `ansible.posix.firewalld` module. The controller needs
the `ansible.posix` collection, and the managed host needs the firewalld Python
bindings when firewalld management runs.

## Libvirt XML

By default, the role writes the generated XML to
`/tmp/mssql-infra-libvirt-networks`. Managed lab networks use routed forwarding,
so traffic between lab subnets is not hidden behind a libvirt NAT gateway:

```xml
<forward mode="route"/>
```

When the selected topology enables `outbound_nat`, nftables handles outbound
internet access separately:

```nft
ip saddr @lab_cidrs ip daddr != @lab_cidrs oifname != @lab_bridges masquerade
```

## DHCP reservations

When `libvirt_host_network_generate_xml` is enabled, the role syncs DHCP host
reservations from the dynamic inventory after the network is started. Each host
with an `interfaces.declared` entry for the network gets a
`<host mac="MAC" name="NAME" ip="IP"/>` reservation, so dnsmasq assigns it a
deterministic IP.

The role applies pure additions with `virsh net-update add --config --live`,
which updates both the persistent XML and the running dnsmasq process without
interruption.

IP changes, MAC changes, and deletions require a brief network restart, so that
the correct IP is served on the next VM boot. The dnsmasq process in libvirt
runs with `--leasefile-ro --dhcp-script`, so it does not reload its in-memory
lease table from disk on SIGHUP. An old lease persists in memory even after
`virsh net-update --live` rewrites the hostsfile, and dnsmasq serves the stale
IP. When the role finds any deletion or modification, it applies additions with
`--config` only (no `--live`), because the network is restarted immediately
afterward. The role restarts the network in this order:

1. `virsh net-update --config`: delete, modify, or add entries in the
   persistent XML. This preserves the network UUID, and `net-start` regenerates
   the hostsfile from the persistent XML.
2. `virsh net-destroy`: stop dnsmasq and tear down the bridge.
3. Remove stale entries from `vibrN.status`, so dnsmasq does not reload the old
   lease when it reinitializes from the file on startup.
4. `virsh net-start`: start dnsmasq fresh. It regenerates the hostsfile from the
   updated persistent XML and reads the clean `vibrN.status`.

## States

* `present`: Define the selected networks, enable autostart, start them, and
  sync DHCP reservations from inventory.
* `absent`: Stop the selected networks and disable autostart.
* `purged`: Stop the selected networks, disable autostart, and undefine them.

To replace an existing network definition with the generated one, set
`libvirt_host_network_redefine: true`. Structural changes, such as a new bridge
name, subnet, or forward mode, require it.

## Example

```yml
- name: manage libvirt lab networks
  hosts: localhost
  become: true
  roles:
    - role: libvirt_host_network
```
