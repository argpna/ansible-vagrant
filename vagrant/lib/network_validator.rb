require 'open3'

module NetworkValidator
  module_function

  def network_statuses(all_vars, network_names: nil, expected_dhcp: {})
    expected_networks = (network_names || (all_vars['networks'] || {}).keys).map(&:to_s).uniq
    networks = all_vars['networks'] || {}

    expected_networks.each_with_object({}) do |network_name, out|
      out[network_name] = inspect_network(networks, network_name, expected_dhcp: expected_dhcp)
    end
  end

  def validate!(all_vars, network_names: nil, expected_dhcp: {})
    network_statuses(all_vars, network_names: network_names, expected_dhcp: expected_dhcp).each do |network_name, status|
      next if status[:state] == :ok

      raise network_error_message(network_name, status)
    end
  end

  def inspect_network(networks, network_name, expected_dhcp: {})
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

    structural = structural_failed_checks(stdout, expected)
    dhcp = dhcp_failed_checks(stdout, Array(expected_dhcp[network_name]))
    all_failed = structural + dhcp

    return { state: :ok } if all_failed.empty?

    {
      state: :mismatch,
      structural: structural.any?,
      failed_checks: all_failed,
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
          ansible-playbook playbooks/libvirt-host-network.yml#{' -e libvirt_host_network_redefine=true' if status[:structural]}
        Halt guests attached to #{network_name.inspect} first if needed.
      MSG
    else
      "Unexpected libvirt network status for #{network_name.inspect}: #{status.inspect}"
    end
  end

  def structural_failed_checks(xml, expected)
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

  def dhcp_failed_checks(xml, expected_hosts)
    return [] if expected_hosts.empty?

    current = parse_dhcp_hosts(xml)
    current_by_mac = current.each_with_object({}) { |h, acc| acc[h['mac']] = h }

    failures = []

    expected_hosts.each do |eh|
      mac = eh['mac']
      ch = current_by_mac[mac]
      if ch.nil?
        failures << "missing DHCP reservation for #{eh['name']} (#{mac} → #{eh['ip']})"
      elsif ch['ip'] != eh['ip']
        failures << "DHCP IP mismatch for #{eh['name']} (#{mac}: expected #{eh['ip']}, got #{ch['ip']})"
      end
    end

    expected_macs = expected_hosts.map { |h| h['mac'] }.to_set
    current_by_mac.each_key do |mac|
      next if expected_macs.include?(mac)

      h = current_by_mac[mac]
      failures << "unexpected DHCP reservation for #{h['name'] || 'unknown'} (#{mac} → #{h['ip']})"
    end

    failures
  end

  def parse_dhcp_hosts(xml)
    xml.scan(/<host\b([^>]*)\/?>/).filter_map do |attrs_str,|
      mac = attrs_str.match(/\bmac=['"]([^'"]+)['"]/)&.captures&.first
      name = attrs_str.match(/\bname=['"]([^'"]+)['"]/)&.captures&.first
      ip = attrs_str.match(/\bip=['"]([^'"]+)['"]/)&.captures&.first
      { 'mac' => mac, 'name' => name, 'ip' => ip } if mac && ip
    end
  end

  def xml_attr(xml, element, attr)
    match = xml.match(/<#{Regexp.escape(element)}\b[^>]*\b#{Regexp.escape(attr)}=(['"])(.*?)\1/m)
    match && match[2]
  end
end
