# Ansible libvirt_host_network role

## Overview

Manages libvirt lab networks on the host. The role resolves the active
network inventory, defines or removes the configured libvirt networks, and
manages firewalld plus scoped outbound NAT for those networks.

## Variables

### Mandatory Variables

* `networks`: Network definitions keyed by network name.

### Optional Variables

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

Firewalld is not assumed to be present. That matters for apt-based hosts, where
firewalld is usually not the default firewall service.

Topologies can enable firewalld management to make sure broad libvirt-zone
masquerade is disabled before WSFC/AG traffic is tested.

Firewalld management behavior:

- if `firewall-cmd` exists and firewalld is running, manage the configured zone
- if firewalld is missing or stopped, skip firewalld changes
- outbound NAT is managed separately with nftables when enabled

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

Set `libvirt_host_network_firewalld_fail_if_unavailable: true` when firewalld is
required for a specific host policy.

The actual zone change uses `ansible.posix.firewalld`. That collection must be
available on the controller, and firewalld's Python bindings must be available
on the managed host when firewalld management runs.

## Libvirt XML

By default the role generates XML into `/tmp/mssql-infra-libvirt-networks`.
Managed lab networks use routed forwarding so traffic between lab subnets is
not hidden behind a libvirt NAT gateway:

```xml
<forward mode="route"/>
```

Outbound internet access is handled separately by nftables when the selected
topology enables `outbound_nat`:

```nft
ip saddr @lab_cidrs ip daddr != @lab_cidrs oifname != @lab_bridges masquerade
```

## DHCP Reservations

When `libvirt_host_network_generate_xml` is enabled, the role syncs DHCP host
reservations from the dynamic inventory after the network is started. Each host
with an `interfaces.declared` entry for the network gets a `<host mac="..."
name="..." ip="..."/>` reservation so dnsmasq assigns it a deterministic IP.

**Pure additions** are applied with `virsh net-update add --config --live`,
updating both the persistent XML and the running dnsmasq process without any
interruption.

**IP changes, MAC changes, and deletions** require a brief network restart to
guarantee the correct IP is served on the next VM boot. libvirt's dnsmasq runs
with `--leasefile-ro --dhcp-script`, so its in-memory lease table is never
reloaded from disk on SIGHUP. An old lease persists in memory even after
`virsh net-update --live` rewrites the hostsfile, causing the stale IP to be
served. When any deletion or modification is present, additions are also applied
with `--config` only (no `--live`), since the network is restarted immediately
after. The restart sequence is:

1. `virsh net-update --config` - delete/modify/add entries in the persistent XML
   (preserves the network UUID; `net-start` regenerates the hostsfile from this)
2. `virsh net-destroy` - kill dnsmasq and tear down the bridge
3. Remove stale entries from `vibrN.status` - so dnsmasq does not reload the old
   lease when it re-initialises from that file on startup
4. `virsh net-start` - start dnsmasq fresh; it regenerates the hostsfile from the
   updated persistent XML and reads the clean `vibrN.status`

## States

- `present`: define the selected networks, enable autostart, start them, and
  sync DHCP reservations from inventory
- `absent`: stop the selected networks and disable autostart
- `purged`: stop, disable autostart, and undefine the selected networks

Set `libvirt_host_network_redefine: true` when an existing network definition
must be replaced by the generated definition - required for structural changes
such as bridge name, subnet, or forward mode.

## Example

```yml
- name: manage libvirt lab networks
  hosts: localhost
  become: true
  roles:
    - role: libvirt_host_network
```
