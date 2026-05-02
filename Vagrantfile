# -*- mode: ruby -*-

require 'shellwords'

require_relative 'vagrant/lib/cli'
require_relative 'vagrant/lib/common'
require_relative 'vagrant/lib/inventory'
require_relative 'vagrant/lib/network'
require_relative 'vagrant/lib/network_validator'
require_relative 'vagrant/lib/provider_options'

ROOT = File.expand_path(File.dirname(__FILE__))
INVENTORY_SCRIPT = File.join(ROOT, 'inventory', 'inventory.py')
GROUP_VARS_ALL = File.join(ROOT, 'inventory', 'group_vars', 'all')
PLAYBOOKS_DIR = File.join(ROOT, 'playbooks')
MAIN_PLAYBOOK = File.join(PLAYBOOKS_DIR, 'main.yml')

def usage
  puts <<~HELP

    All standard vagrant commands work as usual.

    This Vagrantfile is inventory driven. Hosts and groups come from
    inventory/inventory.py, which is the single resolved inventory contract for both
    direct Ansible and Vagrant provisioning.

    Usage:
      VAGRANT_GROUP=<group|host1,host2> vagrant up [args]
      NETWORK_PROFILE=<default|sql-ag> vagrant up [args]

    Ansible:
      ANSIBLE_EXTRA_ARGS="--tags foo -vvv" vagrant up <host>

    Use the --help flag to display the default vagrant help.
  HELP
end

if ARGV.include?('--custom-help')
  usage
  abort
end

all_vars = VagrantCommon.load_group_vars(GROUP_VARS_ALL)
ansible_inventory = VagrantCommon.run_json_command(INVENTORY_SCRIPT, '--list')
resolved_hosts = VagrantInventory.flatten_resolved_hosts(ansible_inventory)
raise 'No hosts found in inventory' if resolved_hosts.empty?

group_env = VagrantCommon.env_str('VAGRANT_GROUP')
selectors = (group_env || '').split(/[,\s]+/).reject(&:empty?)
cli_machine_names = VagrantCli.extract_machine_names(ARGV)
strict_network_topology = VagrantCli.validate_network_topology?(ARGV)
ansible_provision_requested = VagrantCli.ansible_provision?(ARGV)
network_profile = VagrantNetwork.network_profile(all_vars['network_profile'] || 'default')

group_targets = if selectors.empty?
  resolved_hosts
else
  VagrantCli.select_targets(resolved_hosts, selectors)
end
abort "No matching hosts for VAGRANT_GROUP=#{group_env}" if group_targets.empty?

provision_target_names =
  if cli_machine_names.empty?
    group_targets.keys
  else
    cli_machine_names.select { |name| group_targets.key?(name) }
  end
provision_target_names = group_targets.keys if provision_target_names.empty?
ansible_limit = provision_target_names.join(':')
ansible_provision_owner = provision_target_names.last
provision_target_os = provision_target_names.map { |name| resolved_hosts[name]['os'] }.uniq

NetworkValidator.validate!(all_vars, profile_name: network_profile) if strict_network_topology

Vagrant.configure('2') do |config|
  config.vm.synced_folder '.', '/vagrant', disabled: true, id: 'vagrant-root'

  group_targets.each do |name, resolved|
    os = resolved['os']
    box = resolved['vagrant_box']
    connection = resolved['connection']
    provider = resolved['provider_options'] || {}
    interfaces = resolved.fetch('interfaces')
    declared_interfaces = Array(interfaces.fetch('declared'))
    attached_interface_names = Array(interfaces.fetch('attached'))
    declared_interface_names = declared_interfaces.map { |network_interface| network_interface['name'] }
    unknown_attached_interfaces = attached_interface_names - declared_interface_names
    attached_interfaces = declared_interfaces.select { |network_interface| attached_interface_names.include?(network_interface['name']) }

    raise "Host #{name}: os required" if os.to_s.empty?
    raise "Host #{name}: vagrant_box required" if box.to_s.empty?
    raise "Host #{name}: attached interfaces reference unknown declared interfaces: #{unknown_attached_interfaces.join(', ')}" unless unknown_attached_interfaces.empty?
    raise "Host #{name}: at least one attached interface is required" if attached_interfaces.empty?

    config.vm.define name do |vm|
      vm.vm.box = box
      vm.vm.hostname = name

      if os == 'windows'
        vm.vm.communicator = 'winrm'
        vm.winrm.username = connection['ansible_user']
        vm.winrm.password = connection['ansible_password']
      else
        vm.vm.communicator = 'ssh'
        vm.ssh.username = connection['ansible_user']
      end

      attached_interfaces.each do |network_interface|
        vm.vm.network :private_network, **VagrantNetwork.vagrant_options(name, network_interface)
      end

      vm.vm.provider :libvirt do |lv|
        lv.mgmt_attach = false
        ProviderOptions.apply_provider_options(lv, name, provider)
      end

      ProviderOptions.apply_sync_folders(vm, name, provider)

      if name == ansible_provision_owner
        vm.vm.provision 'ansible' do |ans|
          ans.playbook = MAIN_PLAYBOOK
          ans.inventory_path = INVENTORY_SCRIPT
          ans.limit = ansible_limit
          ans.force_remote_user = false

          extra = VagrantCommon.env_str('ANSIBLE_EXTRA_ARGS')
          raw_arguments = []
          raw_arguments += ['--connection=psrp'] if provision_target_os == ['windows']
          raw_arguments += Shellwords.split(extra) if extra
          ans.verbose = :v unless extra&.match?(/(^|\s)-v{1,5}\b/)
          ans.raw_arguments = raw_arguments unless raw_arguments.empty?
        end
      end
    end
  end
end
