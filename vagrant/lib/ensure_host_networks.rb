require 'json'
require 'open3'

require_relative 'common'
require_relative 'network_validator'

module EnsureHostNetworks
  module_function

  ROOT = File.expand_path('../..', __dir__)
  GROUP_VARS_ALL = File.join(ROOT, 'inventory', 'group_vars', 'all')
  PLAYBOOK = File.join(ROOT, 'playbooks', 'libvirt-host-network.yml')

  def run!(network_names)
    selected_names = Array(network_names).map(&:to_s).map(&:strip).reject(&:empty?).uniq
    return if selected_names.empty?

    all_vars = VagrantCommon.load_group_vars(GROUP_VARS_ALL)
    statuses = NetworkValidator.network_statuses(all_vars, network_names: selected_names)

    unknown = statuses.select { |_name, status| status[:state] == :unknown }.keys
    raise "Unknown lab networks: #{unknown.join(', ')}" unless unknown.empty?

    missing = statuses.select { |_name, status| status[:state] == :missing }.keys
    mismatched = statuses.select { |_name, status| status[:state] == :mismatch }.keys

    run_playbook!(missing) unless missing.empty?
    run_playbook!(mismatched, redefine: true) unless mismatched.empty?

    NetworkValidator.validate!(all_vars, network_names: selected_names)
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
