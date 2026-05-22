# Ansible & Vagrant

> [!NOTE]
> This repo is based on [jborean93/ansible-windows](https://github.com/jborean93/ansible-windows), but has been reworked for Vagrant with the libvirt provider.

This repo contains Ansible roles, playbooks and a libvirt-backed Vagrant workflow to
build and manage Windows and Linux VMs (weighted more towards mssql infrastructure).

It can also be used as a general-purpose infrastructure repository when Vagrant provisioning
is omitted.

## Requires

* Vagrant
* libvirt
* the `vagrant-libvirt` plugin
* Python 3 on the host system running Vagrant
* Ansible on the host system running Vagrant, either from your existing setup or from the optional repo-local host virtualenv

## Host Ansible Setup

> [!NOTE]
> If you already have a working host Ansible setup, you can keep using it
> and skip this step.

This repo includes a minimal host bootstrap that creates `.venv`,
installs the pinned Ansible and Python packages from
[requirements-host.txt](requirements-host.txt), and installs the required
collections from [requirements-host.yml](requirements-host.yml):

```bash
./bootstrap/setup-host-venv.sh
source .venv/bin/activate
```

This host `.venv` is only for bootstrapping and host-side execution. The repo's
primary Ansible toolchain still lives inside the control node VM at
`/home/ansible/controller-venv`.

To use that in-VM toolchain after the control node is provisioned:

```bash
vagrant ssh ansible-con-01
enter-ansible-env
```

`enter-ansible-env` switches to the controller admin user and activates the
control-node virtualenv for that shell.

This repo needs Ansible on the host to drive `vagrant up --provision` and any
direct host-side `ansible-playbook` runs.

## Provisioning

This repo provisions the lab from the dynamic inventory in
[inventory/inventory.py](inventory/inventory.py), which resolves host data from
[inventory/hosts.yml](inventory/hosts.yml), [inventory/hosts.d](inventory/hosts.d),
and [inventory/group_vars](inventory/group_vars). Vagrant uses that resolved
inventory to run [playbooks/main.yml](playbooks/main.yml) against the selected
hosts with the appropriate Ansible host limit.

The provisioning flow covers:

* A Linux control node for Ansible and module development work
* Standalone Linux hosts
* A Windows domain controller
* Windows domain member hosts
* AD CS with machine auto-enrollment
* WinRM HTTPS listener certificates issued by the lab CA
* Optional Guest tools and OpenSSH on Windows boxes

The Linux control node is the intended working environment for the repo's
Ansible toolchain. It builds its own Python and virtualenv, then installs
Ansible and the required Windows connection dependencies there instead of
depending on the base VM Python environment.

> [!NOTE]
> If you only want to spin up standalone Vagrant hosts and do not need the
> Ansible control-node workflow or the lab domain setup, use `--no-provision`
> with `vagrant up`. This skips guest provisioning, but Vagrant still ensures
> the selected host's libvirt networks exist on the host first.


## Inventory Layout

The inventory is organized by host role:

* `control_node` -
  the Linux Ansible control node
* `linux_hosts` -
  optional non-controller Linux hosts and the parent group for Linux MSSQL validation hosts
* `domain_controller` -
  the Windows domain controller
* `domain_members` -
  Windows domain-joined member hosts, currently Windows MSSQL test hosts
* `mssql_windows_matrix` -
  standalone Windows MSSQL install validation matrix
* `mssql_linux_matrix` -
  Linux MSSQL install validation matrix, with `mssql_linux_apt`, `mssql_linux_dnf`, and `mssql_linux_unsupported` subgroups
* `mssql_windows_ag` -
  Windows SQL Server availability group test nodes using WSFC
* `mssql_linux_ag` -
  Linux SQL Server availability group test nodes

Core hosts live in `inventory/hosts.yml`. MSSQL host definitions live in
`inventory/hosts.d/mssql_linux.yml` and `inventory/hosts.d/mssql_windows.yml`, and `inventory.py` exposes the inventory to Ansible and Vagrant.

Shared lab settings live in group vars:

* [all](inventory/group_vars/all) -
  domain, Kerberos, DNS, certificates, provider defaults
* [linux.yml](inventory/group_vars/linux.yml) -
  Linux connection settings and Linux libvirt defaults
* [windows.yml](inventory/group_vars/windows.yml) -
  PSRP connection settings and optional Windows extras
* [control_node.yml](inventory/group_vars/control_node.yml) -
  control-node Python, Ansible, and admin-user settings
* [mssql_windows_ag.yml](inventory/group_vars/mssql_windows_ag.yml) -
  MSSQL cluster, availability groups topology settings
* [mssql_linux_ag.yml](inventory/group_vars/mssql_linux_ag.yml) -
  Linux MSSQL availability groups topology settings (only placeholder at the moment)

Two singleton groups are assumed by the playbooks:

* `control_node`
* `domain_controller`

The playbooks assert that each of those groups contains exactly one host at the moment.

## Role Map

The roles are grouped by responsibility. The per-role README files document
their variables and caveats in more detail.

### Controller roles

These roles prepare the Linux control node used to run Ansible, PSRP, WinRM,
and repo-local tooling.

* [linux_base](roles/linux_base/README.md) -
  installs baseline Linux packages, creates the controller admin user and
  group, installs the authorized key, and grants passwordless sudo
* [linux_kerberos_client](roles/linux_kerberos_client/README.md) -
  installs Kerberos and DNS client pieces and renders the local Kerberos and
  resolver configuration needed to talk to the AD lab
* [controller_python](roles/controller_python/README.md) -
  builds the configured Python from source, validates the interpreter version,
  and creates the controller virtualenv
* [controller_ansible](roles/controller_ansible/README.md) -
  installs Ansible plus the Windows controller dependencies into that virtualenv
  and adds the `enter-ansible-env` shell helper

These roles are normally driven together by
[controller-node.yml](playbooks/controller-node.yml).

### Libvirt host roles

These roles manage libvirt host-side prerequisites.

* [libvirt_host_network](roles/libvirt_host_network/README.md) -
  reads the configured lab networks from inventory, generates libvirt network
  XML, defines and starts the routed lab networks, and optionally manages
  firewalld plus scoped nftables outbound NAT
* [libvirt_host_share](roles/libvirt_host_share/README.md) -
  validates host share records, resolves the effective libvirt domain name,
  renders virtiofs filesystem XML, and attaches the shares to the persistent
  and optionally live domain definition

These roles are typically driven by:

* [libvirt-host-network.yml](playbooks/libvirt-host-network.yml)
* [libvirt-host-share.yml](playbooks/libvirt-host-share.yml)

### Windows platform roles

These roles build the Windows lab platform itself before SQL Server or WSFC
work starts.

* [windows_domain_controller](roles/windows_domain_controller/README.md) -
  points DNS at localhost, promotes the host to a domain controller, creates
  the initial domain admin, and validates that identity
* [windows_domain_member](roles/windows_domain_member/README.md) -
  points member hosts at the DC for DNS, joins them to the domain, reboots when
  needed, and validates domain logon
* [windows_adcs](roles/windows_adcs/README.md) -
  installs the CA, publishes the auto-enrollment template, configures the GPO,
  and exports the CA chain
* [windows_winrm_cert](roles/windows_winrm_cert/README.md) -
  refreshes policy, triggers certificate enrollment, locates the correct issued
  certificate, and rebinds the WinRM HTTPS listener when needed
* [windows_common](roles/windows_common/README.md) -
  provides repo-local helper modules used by the Windows roles so connection,
  certificate, and SQL flows do not have to duplicate inline PowerShell logic

These roles are split across:

* [windows-domain-controller.yml](playbooks/windows-domain-controller.yml)
* [windows-domain-members.yml](playbooks/windows-domain-members.yml)
* [windows-certificates.yml](playbooks/windows-certificates.yml)

### Windows SQL and cluster roles

These roles are the SQL Server and WSFC-focused part of the repo.

* [windows_sql_server](roles/windows_sql_server/README.md) -
  manages SQL Server setup by handling service accounts first and then driving
  Microsoft `setup.exe` with repo-local modules and inventory-backed SQL
  settings
* [windows_failover_cluster](roles/windows_failover_cluster/README.md) -
  exposes operation-specific WSFC entrypoints such as prerequisites, file share
  witness, and cluster creation instead of forcing everything through one large
  cluster task file

Primary playbooks:

* [windows-sql-server.yml](playbooks/windows-sql-server.yml)
* [windows-failover-cluster.yml](playbooks/windows-failover-cluster.yml)

### Optional Windows utility roles

These roles are optional and are not treated as baseline requirements for every Windows host.

* [windows_guest_tools](roles/windows_guest_tools/README.md) -
  installs WinFSP and virtio guest tools, then configures virtiofs tag-to-drive
  mounts when host shares are present
* [windows_openssh](roles/windows_openssh/README.md) -
  installs the OpenSSH Server capability and manages the service, firewall
  rule, and default shell

Utility playbooks:

* [windows-guest-tools.yml](playbooks/windows-guest-tools.yml)
* [windows-openssh.yml](playbooks/windows-openssh.yml)

## Control Node Flow

The control-node playbook is [controller-node.yml](playbooks/controller-node.yml). It runs:

* [linux_base](roles/linux_base/README.md)
* [linux_kerberos_client](roles/linux_kerberos_client/README.md)
* [controller_python](roles/controller_python/README.md)
* [controller_ansible](roles/controller_ansible/README.md)

which produces:

* A Linux admin user (with passwordless sudo)
* Kerberos and DNS configuration so the control node can resolve and reach the AD lab
* A Python runtime built from source (to avoid distro-specific package related complexities)
* A control-node virtualenv at `/home/ansible/controller-venv`
* `ansible`, `pypsrp`, `pywinrm`, `requests-kerberos`, `requests-credssp`, and `gssapi` installed inside that virtualenv
* `/usr/local/bin/enter-ansible-env`, which switches to the controller admin user and activates the control-node virtualenv

Current control-node defaults from [control_node.yml](inventory/group_vars/control_node.yml):

* Python line: `3.11`
* source build version: `3.11.1`
* virtualenv path: `/home/ansible/controller-venv`
* Ansible package: `ansible==12.3.0`

These are defaults in inventory. Modify them accordingly if you want a different control-node toolchain.

## Windows Domain Flow

The Windows domain lifecycle is split into separate playbooks:

* [windows-domain-controller.yml](playbooks/windows-domain-controller.yml)
  promotes the controller and creates the initial domain admin
* [windows-domain-members.yml](playbooks/windows-domain-members.yml)
  joins member hosts to the domain and validates domain logon
* [windows-certificates.yml](playbooks/windows-certificates.yml)
  configures AD CS and updates WinRM HTTPS listeners for the controller and members

The Windows flow uses:

* [windows_domain_controller](roles/windows_domain_controller/README.md)
  promote the DC and create the initial domain admin
* [windows_domain_member](roles/windows_domain_member/README.md)
  point DNS at the DC, join the domain, reboot if needed
* [windows_adcs](roles/windows_adcs/README.md)
  install the CA, publish the machine template, configure the auto-enrollment GPO, export the CA chain
* [windows_winrm_cert](roles/windows_winrm_cert/README.md)
  enroll/select the correct machine certificate and rebind the WinRM HTTPS listener

When AD CS is enabled, [windows-certificates.yml](playbooks/windows-certificates.yml) also writes [ca_chain.pem](ca_chain.pem) in the repo root. The Windows connection defaults use that file to switch PSRP from certificate validation `ignore` during bootstrap to validated HTTPS once the lab CA chain is available. After the chain exists locally, PSRP connects to the Windows host FQDN instead of the inventory IP so the WinRM listener certificate can be validated against its DNS SAN.

## Optional Windows Utilities

Additional utility playbooks are available:

* [windows-guest-tools.yml](playbooks/windows-guest-tools.yml)
  install SPICE, WinFSP, and VirtIO guest tools through [windows_guest_tools](roles/windows_guest_tools/README.md)
* [windows-openssh.yml](playbooks/windows-openssh.yml)
  install and configure the Windows OpenSSH Server capability through [windows_openssh](roles/windows_openssh/README.md)

When running [main.yml](playbooks/main.yml), the guest-tools and OpenSSH utility
imports are tagged `never`. Run them explicitly with `--tags windows_guest_tools`
or `--tags windows_openssh` when you want those utility flows included.

## Provider Options

Provider settings are inventory-driven. The Vagrant provider helper currently accepts: `cpus`, `memory_mb`, `cpu_mode`, `nic_model`, `video_type`, `graphics`, `memory_backing`, `sync_folders`

Additional options can be included by extending `ProviderOptions::ALLOWED` in [provider_options.rb](vagrant/lib/provider_options.rb).

For example, to add support for CPU topology

```ruby
ALLOWED = %w[
  ...
  ...
  cpu_topology
].freeze
```

Then update `ProviderOptions.apply_provider_options` and append something like

```ruby
if opts['cpu_topology'].is_a?(Hash)
  topo = opts['cpu_topology']
  lv.cputopology(
    sockets: Integer(topo['sockets']),
    cores: Integer(topo['cores']),
    threads: Integer(topo['threads'])
  )
end
```

And define it in the inventory

```yaml
provider_options:
  ...
  cpu_mode: host-model
  cpu_topology:
    sockets: 2
    cores: 2
    threads: 1
  ...
```

Better validation, error handling etc can be added as needed. The idea is to keep things flexible and let the inventory drive what gets exposed.

> [!NOTE]
> Vagrant libvirt documentation reference can be found
> [here](https://vagrant-libvirt.github.io/vagrant-libvirt/configuration.html)

Global defaults come from [inventory/group_vars/all](inventory/group_vars/all), with Linux and Windows overlays from [linux.yml](inventory/group_vars/linux.yml) and [windows.yml](inventory/group_vars/windows.yml). Host-level `provider_options` override those merged defaults.

Linux sync-folder defaults currently enable read-write `virtiofs` for the repo root at `/vagrant`.

## Vagrant Networking

Host networking comes from the resolved inventory interface data in
[inventory/inventory.py](inventory/inventory.py).

When you run `vagrant up <host>`, `vagrant reload <host>`, or `vagrant resume <host>`,
Vagrant first ensures the libvirt networks attached to that host exist on the
host system. For example:

* `ansible-con-01` ensures `lab-main`
* `win-cluster-n01` ensures `mssql-main`
* `win-cluster-n02` ensures `mssql-dr`

The host-side network definitions are managed by
[libvirt-host-network.yml](playbooks/libvirt-host-network.yml).

## Vagrant Provision

Bring up a specific host:

```sh
vagrant up ansible-con-01 --provision
```

Bring up multiple hosts:

```sh
vagrant up domain-con-01 win-cluster-n01 --provision
```

Select targets with `VAGRANT_GROUP`:

```sh
VAGRANT_GROUP=linux vagrant up --provision
VAGRANT_GROUP=control_node vagrant up --provision
VAGRANT_GROUP=domain_controller,domain_members vagrant up --provision
```

Pass raw Ansible flags with `ANSIBLE_EXTRA_ARGS`:

```sh
ANSIBLE_EXTRA_ARGS="-vv --forks=2" vagrant up domain-con-01 --provision
```

Show the custom Vagrantfile help:

```sh
vagrant --custom-help
```
