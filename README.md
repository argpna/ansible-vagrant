# Ansible & Vagrant

> [!NOTE]
> This repository is based on [jborean93/ansible-windows](https://github.com/jborean93/ansible-windows),
> but has been reworked for Vagrant with the libvirt provider.

This repository contains Ansible roles, playbooks, and a libvirt-backed Vagrant
workflow to build and manage Windows and Linux virtual machines (VMs), primarily
for SQL Server infrastructure. You can also run the roles and playbooks without
Vagrant.

## Requirements

* Vagrant
* libvirt
* the `vagrant-libvirt` plugin
* Python 3 on the host system running Vagrant
* Ansible on the host system running Vagrant, either installed already or from
  the optional host virtualenv in this repository

## Host Ansible setup

The host bootstrap script creates `.venv`, installs the pinned Ansible and
Python packages from [`requirements-host.txt`](requirements-host.txt), and
installs the required collections from [`requirements-host.yml`](requirements-host.yml):

```bash
./bootstrap/setup-host-venv.sh
source .venv/bin/activate
```

The host `.venv` is only for bootstrapping and host-side execution. The primary
Ansible toolchain lives in the control node VM at `/home/ansible/controller-venv`.

To use the in-VM toolchain, do the following:

1. On the host, start and provision the control node:

   ```bash
   vagrant up ansible-con-01 --provision
   ```

2. On the host, connect to the control node:

   ```bash
   vagrant ssh ansible-con-01
   ```

3. In the control node, run `enter-ansible-env`.

The `enter-ansible-env` command switches to the control-node admin user and
activates the control-node virtualenv.

## Lab provisioning

The lab is provisioned from the dynamic inventory in
[`inventory/inventory.py`](inventory/inventory.py), which resolves host data from
[`inventory/hosts.yml`](inventory/hosts.yml), [`inventory/hosts.d`](inventory/hosts.d),
and [`inventory/group_vars`](inventory/group_vars). Vagrant uses the resolved
inventory to run [`playbooks/main.yml`](playbooks/main.yml) with the Ansible
`--limit` set to the selected hosts.

The provisioning flow creates the following:

* A Linux control node for running Ansible and developing modules
* Standalone Linux hosts
* A Windows domain controller
* Windows domain member hosts
* Active Directory Certificate Services (AD CS) with machine auto-enrollment
* WinRM HTTPS listener certificates issued by the lab certificate authority (CA)
* Optional guest tools and OpenSSH on Windows hosts

The Linux control node is the working environment for the Ansible toolchain. It
builds its own Python and virtualenv, then installs Ansible and the required
Windows connection dependencies there.

To start standalone Vagrant hosts without the control-node workflow or the lab
domain setup, run `vagrant up` with `--no-provision`.

## Inventory layout

The inventory is organized by host role:

* `control_node`: the Linux Ansible control node
* `linux_hosts`: optional Linux hosts other than the control node, and the parent group for Linux SQL Server validation hosts
* `domain_controller`: the Windows domain controller
* `domain_members`: Windows domain-joined member hosts, such as the Windows SQL Server test hosts
* `mssql_windows_matrix`: standalone Windows SQL Server install validation matrix
* `mssql_linux_matrix`: Linux SQL Server install validation matrix, with `mssql_linux_apt` and `mssql_linux_dnf` subgroups
* `mssql_linux_unsupported`: Linux hosts on platforms SQL Server does not support, used for negative tests
* `mssql_windows_ag`: Windows SQL Server availability group test nodes using Windows Server Failover Clustering (WSFC)
* `mssql_linux_ag`: Linux SQL Server availability group test nodes

These groups serve the `argpna.mssql` integration test suites:

* `mssql_install_targets`: supported matrix hosts for the install and remove suites, which cover SQL Server features and options
* `mssql_manage_targets`: hosts for the management suite, with one host per SQL Server version and OS family

The management suite expects a running engine.

Core hosts live in `inventory/hosts.yml`. SQL Server host definitions live in
`inventory/hosts.d/mssql_linux.yml` and `inventory/hosts.d/mssql_windows.yml`, and
the `argpna.mssql` test suite groups live in `inventory/hosts.d/mssql_targets.yml`.
The `inventory.py` script exposes the inventory to Ansible and Vagrant. Define each
host in one group. Another group can reference that host under `members`.

Shared lab settings live in group vars:

* [`group_vars/all`](inventory/group_vars/all): domain, Kerberos, DNS, certificates, provider defaults
* [`linux.yml`](inventory/group_vars/linux.yml): Linux connection settings and Linux libvirt defaults
* [`windows.yml`](inventory/group_vars/windows.yml): PowerShell Remoting Protocol (PSRP) connection settings and optional Windows extras
* [`control_node.yml`](inventory/group_vars/control_node.yml): control-node Python, Ansible, and admin-user settings
* [`mssql_windows_ag.yml`](inventory/group_vars/mssql_windows_ag.yml): SQL Server cluster and availability group topology settings
* [`mssql_linux_ag.yml`](inventory/group_vars/mssql_linux_ag.yml): Linux SQL Server install settings, Pacemaker cluster settings, and availability group topology

The playbooks assert that each of the following groups contains only one host:

* `control_node`
* `domain_controller`

## Role map

The roles are grouped by responsibility. The per-role README files document
their variables and caveats in more detail.

### Control-node roles

These roles prepare the Linux control node used to run Ansible, PSRP, and WinRM,
along with the tooling in this repository.

* [`linux_base`](roles/linux_base/README.md): installs baseline Linux packages, creates the control-node admin user and group, installs the authorized key, and grants passwordless sudo.
* [`linux_kerberos_client`](roles/linux_kerberos_client/README.md): installs Kerberos and DNS client pieces and renders the local Kerberos and resolver configuration needed to reach the lab domain.
* [`controller_python`](roles/controller_python/README.md): builds the configured Python from source, validates the interpreter version, and creates the control-node virtualenv.
* [`controller_ansible`](roles/controller_ansible/README.md): installs Ansible and the Windows connection dependencies into the virtualenv and adds the `enter-ansible-env` shell helper.

The [`controller-node.yml`](playbooks/controller-node.yml) playbook runs these
roles together.

### Libvirt host roles

These roles manage libvirt host-side prerequisites.

* [`libvirt_host_network`](roles/libvirt_host_network/README.md): reads the configured lab networks from inventory, generates libvirt network XML, defines and starts the routed lab networks, and optionally manages firewalld and scoped nftables outbound network address translation (NAT).
* [`libvirt_host_share`](roles/libvirt_host_share/README.md): validates host share records, resolves the effective libvirt domain name, renders virtiofs filesystem XML, and attaches the shares to the persistent and optionally live domain definition.

These roles run from the following playbooks:

* [`libvirt-host-network.yml`](playbooks/libvirt-host-network.yml)
* [`libvirt-host-share.yml`](playbooks/libvirt-host-share.yml)

### Windows platform roles

These roles build the Windows lab platform before SQL Server or WSFC work starts.

* [`windows_domain_controller`](roles/windows_domain_controller/README.md): points DNS at localhost, promotes the host to a domain controller, and creates the initial domain admin.
* [`windows_domain_member`](roles/windows_domain_member/README.md): points member hosts at the domain controller for DNS, joins them to the domain, and reboots the hosts if needed.
* [`windows_adcs`](roles/windows_adcs/README.md): installs the CA, publishes the auto-enrollment template, configures the auto-enrollment Group Policy object, and exports the CA chain.
* [`windows_winrm_cert`](roles/windows_winrm_cert/README.md): refreshes policy, triggers certificate enrollment, finds the machine certificate issued by the lab CA, and rebinds the WinRM HTTPS listener when needed.
* [`windows_common`](roles/windows_common/README.md): provides helper modules in this repository that the Windows roles share, so connection, certificate, and SQL tasks don't duplicate inline PowerShell.

These roles run from the following playbooks:

* [`windows-domain-controller.yml`](playbooks/windows-domain-controller.yml): promotes the domain controller and creates the initial domain admin
* [`windows-domain-members.yml`](playbooks/windows-domain-members.yml): joins member hosts to the domain and validates domain logon
* [`windows-certificates.yml`](playbooks/windows-certificates.yml): configures AD CS and updates the WinRM HTTPS listeners for the domain controller and members

### Windows SQL and cluster roles

These roles are the SQL Server and WSFC part of the repository.

* [`windows_sql_server`](roles/windows_sql_server/README.md): manages SQL Server setup. It handles service accounts first, then runs Microsoft `setup.exe` with helper modules from this repository and SQL settings from inventory.
* [`windows_failover_cluster`](roles/windows_failover_cluster/README.md): provides separate entry points for prerequisites, the file share witness, and cluster creation.
* [`windows_sql_media`](roles/windows_sql_media/README.md): stages SQL Server install media and the SQL Server Management Studio (SSMS) installer from the mounted host share to fixed guest-local paths.

These roles run from the following playbooks:

* [`windows-sql-server.yml`](playbooks/windows-sql-server.yml)
* [`windows-failover-cluster.yml`](playbooks/windows-failover-cluster.yml)

These playbooks support the `argpna.mssql` integration tests:

* [`mssql-test-prep.yml`](playbooks/mssql-test-prep.yml): attaches and mounts the host shares and stages media on the Windows matrix hosts. On Linux matrix hosts, it installs the Python interpreter that the host's inventory entry expects.
* [`mssql-engine.yml`](playbooks/mssql-engine.yml): installs a standalone SQL Server with mixed mode authentication on the `mssql_manage_targets` hosts, using the shared `mssql_sa_password` when passed. With `-e mssql_engine_state=absent`, it removes the engine and returns the host to a clean state.

### Linux SQL and cluster roles

These roles are the Linux counterparts of the Windows SQL and cluster roles.

* [`linux_domain_member`](roles/linux_domain_member/README.md): points the host at the domain controller for DNS, creates its DNS record in Active Directory, joins the realm through sssd, and validates the domain identity. It runs after `linux_kerberos_client`.
* [`linux_sql_server`](roles/linux_sql_server/README.md): installs and configures SQL Server from the Microsoft repositories and sets up Active Directory authentication through an adutil keytab.
* [`linux_pacemaker_cluster`](roles/linux_pacemaker_cluster/README.md): prepares the nodes, creates or destroys the Pacemaker and Corosync cluster, and provisions the SQL login the cluster resource agent uses.

These roles run from the following playbooks:

* [`linux-domain-members.yml`](playbooks/linux-domain-members.yml)
* [`linux-sql-server.yml`](playbooks/linux-sql-server.yml)
* [`linux-pacemaker-cluster.yml`](playbooks/linux-pacemaker-cluster.yml)

### Optional: Windows utility roles

These roles are optional. Run them on the Windows hosts that need them.

* [`windows_guest_tools`](roles/windows_guest_tools/README.md): installs VirtIO, WinFSP, and SPICE guest tools, then configures virtiofs tag-to-drive mounts when host shares are present.
* [`windows_openssh`](roles/windows_openssh/README.md): installs the OpenSSH Server capability and manages the service, firewall rule, and default shell.

These roles run from the following playbooks:

* [`windows-guest-tools.yml`](playbooks/windows-guest-tools.yml)
* [`windows-openssh.yml`](playbooks/windows-openssh.yml)

## Control-node flow

The `controller-node.yml` playbook runs the following roles:

* `linux_base`
* `linux_kerberos_client`
* `controller_python`
* `controller_ansible`

The playbook produces the following:

* A Linux admin user with passwordless sudo
* Kerberos and DNS configuration so the control node can resolve and reach the lab domain
* A Python runtime built from source, so the Python version doesn't depend on distribution packages
* A control-node virtualenv at `/home/ansible/controller-venv`
* Ansible and its Windows connection dependencies, installed in the virtualenv
* The `/usr/local/bin/enter-ansible-env` command

The Python and Ansible versions, the virtualenv path, and other control-node
settings are defaults in `inventory/group_vars/control_node.yml`. To use a
different toolchain, change them in inventory.

## WinRM certificate validation

When AD CS is enabled, `windows-certificates.yml` also writes
[`ca_chain.pem`](ca_chain.pem) in the repository root. The Windows connection
defaults use that file to switch PSRP from certificate validation `ignore` during
bootstrap to validated HTTPS after the lab CA chain is available. Once the chain
exists locally, PSRP connects to the Windows host's fully qualified domain name
instead of the inventory IP address, so the WinRM listener certificate can be
validated against its DNS subject alternative name.

## Run tagged playbooks

The `playbooks/main.yml` imports for the following playbooks are tagged `never`.
To include one, run `main.yml` with its tag, for example `--tags windows_guest_tools`:

* `windows_guest_tools`
* `windows_openssh`
* `linux_domain_members`
* `linux_sql_server`
* `linux_pacemaker_cluster`
* `mssql_test_prep`
* `mssql_engine`

## Provider options

Provider settings are inventory-driven. The Vagrant provider helper accepts the
options listed in `ProviderOptions::ALLOWED` in
[`provider_options.rb`](vagrant/lib/provider_options.rb).

To add an option, such as CPU topology, do the following:

1. Add `cpu_topology` to `ProviderOptions::ALLOWED` in `provider_options.rb`.
2. In `ProviderOptions.apply_provider_options`, add the following block:

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

3. In the host's inventory entry, set the option:

   ```yaml
   provider_options:
     # other provider options
     cpu_mode: host-model
     cpu_topology:
       sockets: 2
       cores: 2
       threads: 1
   ```

For more information, see the
[vagrant-libvirt configuration reference](https://vagrant-libvirt.github.io/vagrant-libvirt/configuration.html).

Global defaults come from `inventory/group_vars/all`, with Linux and Windows
overlays from `linux.yml` and `windows.yml` in the same directory. Host-level
`provider_options` override those merged defaults.

Linux sync-folder defaults mount the repository root at `/vagrant` with
read-write `virtiofs`.

## Libvirt networks

Host networking comes from the resolved inventory interface data in
`inventory/inventory.py`.

When you run `vagrant up HOST`, `vagrant reload HOST`, or `vagrant resume HOST`,
Vagrant first creates any missing libvirt networks attached to that host on the
host system. For example, `win-cluster-n01` uses `mssql-main`.

The host-side network definitions are managed by `libvirt-host-network.yml`.

## Provision with Vagrant

Start and provision a specific host:

```bash
vagrant up ansible-con-01 --provision
```

Start and provision multiple hosts:

```bash
vagrant up ansible-con-01 domain-con-01 --provision
```

Select targets with `VAGRANT_GROUP`:

```bash
VAGRANT_GROUP=linux vagrant up --provision
VAGRANT_GROUP=control_node vagrant up --provision
VAGRANT_GROUP=domain_controller,domain_members vagrant up --provision
```

Pass raw Ansible flags with `ANSIBLE_EXTRA_ARGS`:

```bash
ANSIBLE_EXTRA_ARGS="-vv --forks=2" vagrant up domain-con-01 --provision
```

Show the custom Vagrantfile help:

```bash
vagrant --custom-help
```
