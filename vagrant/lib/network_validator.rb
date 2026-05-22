require 'open3'

module NetworkValidator
  module_function

  def network_statuses(all_vars, network_names: nil)
    expected_networks = (network_names || (all_vars['networks'] || {}).keys).map(&:to_s).uniq
    networks = all_vars['networks'] || {}

    expected_networks.each_with_object({}) do |network_name, out|
      out[network_name] = inspect_network(networks, network_name)
    end
  end

  def validate!(all_vars, network_names: nil)
    network_statuses(all_vars, network_names: network_names).each do |network_name, status|
      next if status[:state] == :ok

      raise network_error_message(network_name, status)
    end
  end

  def inspect_network(networks, network_name)
    expected = networks[network_name]
    return { state: :unknown } unless expected.is_a?(Hash)

    expected = expected.merge('forward_mode' => expected['forward_mode'] || 'route')
    stdout, stderr, status = Open3.capture3('virsh', 'net-dumpxml', network_name)
    unless status.success?
      return {
        state: :missing,
        stderr: stderr.strip
      }
    end

    failed = failed_checks(stdout, expected)
    return { state: :ok } if failed.empty?

    {
      state: :mismatch,
      failed_checks: failed,
      cidr: expected['cidr']
    }
  end

  def network_error_message(network_name, status)
    case status[:state]
    when :unknown
      "Unknown lab network #{network_name.inspect} in inventory/group_vars/all/network.yml"
    when :missing
      <<~MSG
        Missing libvirt network #{network_name.inspect}.
        Run:
          ansible-playbook playbooks/libvirt-host-network.yml
        virsh error:
          #{status[:stderr]}
      MSG
    when :mismatch
      <<~MSG
        Libvirt network #{network_name.inspect} exists but does not match inventory.
        Failed checks: #{Array(status[:failed_checks]).join(', ')}
        Expected CIDR: #{status[:cidr]}
        Run:
          ansible-playbook playbooks/libvirt-host-network.yml -e libvirt_host_network_redefine=true
        Halt guests attached to #{network_name.inspect} first if needed.
      MSG
    else
      "Unexpected libvirt network status for #{network_name.inspect}: #{status.inspect}"
    end
  end

  def failed_checks(xml, expected)
    bridge = expected['bridge_name'].to_s
    gateway = expected['gateway'].to_s
    netmask = expected['netmask'].to_s

    actual_forward_mode = xml_attr(xml, 'forward', 'mode')

    checks = {
      "forward mode #{expected['forward_mode']} (current #{actual_forward_mode || 'missing'})" => actual_forward_mode == expected['forward_mode'].to_s,
      "bridge #{bridge}" => xml_attr(xml, 'bridge', 'name') == bridge,
      "gateway #{gateway}" => xml_attr(xml, 'ip', 'address') == gateway,
      "netmask #{netmask}" => xml_attr(xml, 'ip', 'netmask') == netmask
    }

    checks.select { |_label, ok| !ok }.keys
  end

  def xml_attr(xml, element, attr)
    match = xml.match(/<#{Regexp.escape(element)}\b[^>]*\b#{Regexp.escape(attr)}=(['"])(.*?)\1/m)
    match && match[2]
  end
end
