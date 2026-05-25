require 'json'
require 'open3'

require_relative 'common'
require_relative 'network_validator'

module EnsureHostNetworks
  module_function

  ROOT = File.expand_path('../..', __dir__)
  GROUP_VARS_ALL = File.join(ROOT, 'inventory', 'group_vars', 'all')
  INVENTORY_SCRIPT = File.join(ROOT, 'inventory', 'inventory.py')
  PLAYBOOK = File.join(ROOT, 'playbooks', 'libvirt-host-network.yml')

  def run!(network_names)
    selected_names = Array(network_names).map(&:to_s).map(&:strip).reject(&:empty?).uniq
    return if selected_names.empty?

    all_vars = VagrantCommon.load_group_vars(GROUP_VARS_ALL)
    ansible_inventory = VagrantCommon.run_json_command(INVENTORY_SCRIPT, '--list')
    expected_dhcp = dhcp_entries_by_network(ansible_inventory)

    statuses = NetworkValidator.network_statuses(all_vars, network_names: selected_names, expected_dhcp: expected_dhcp)

    unknown = statuses.select { |_name, status| status[:state] == :unknown }.keys
    raise "Unknown lab networks: #{unknown.join(', ')}" unless unknown.empty?

    missing = statuses.select { |_name, status| status[:state] == :missing }.keys
    structural_mismatched = statuses.select { |_name, status| status[:state] == :mismatch && status[:structural] }.keys
    dhcp_mismatched = statuses.select { |_name, status| status[:state] == :mismatch && !status[:structural] }.keys

    run_playbook!(missing) unless missing.empty?
    run_playbook!(structural_mismatched, redefine: true) unless structural_mismatched.empty?
    run_playbook!(dhcp_mismatched) unless dhcp_mismatched.empty?

    NetworkValidator.validate!(all_vars, network_names: selected_names, expected_dhcp: expected_dhcp)
  end

  def dhcp_entries_by_network(ansible_inventory)
    hostvars = ansible_inventory.dig('_meta', 'hostvars') || {}
    result = Hash.new { |h, k| h[k] = [] }
    hostvars.each do |host_name, vars|
      Array(vars.dig('interfaces', 'declared') || []).each do |iface|
        network = iface['network'].to_s
        mac = iface['mac'].to_s
        ip = iface['ip'].to_s
        next if network.empty? || mac.empty? || ip.empty?

        result[network] << { 'mac' => mac, 'name' => host_name, 'ip' => ip }
      end
    end
    result
  end

  def run_playbook!(network_names, redefine: false)
    extra_vars = { 'libvirt_host_network_names' => network_names }.to_json
    argv = ['ansible-playbook', PLAYBOOK, '-e', extra_vars]
    argv += ['-e', 'libvirt_host_network_redefine=true'] if redefine

    stdout = ''
    stderr = ''
    status = nil

    Dir.chdir(ROOT) do
      stdout, stderr, status = Open3.capture3(*argv)
    end

    return if status.success?

    action = redefine ? 'redefine' : 'create'
    raise <<~MSG
      Failed to #{action} libvirt networks #{network_names.join(', ')}.
      Command: #{argv.join(' ')}
      stdout:
      #{stdout.strip}
      stderr:
      #{stderr.strip}
    MSG
  end
end
