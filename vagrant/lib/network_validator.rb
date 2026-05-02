require 'open3'

require_relative 'network'

module NetworkValidator
  module_function

  def validate!(all_vars, profile_name: nil, network_names: nil)
    profiles = all_vars['network_profiles'] || {}
    profile = profile_name || VagrantNetwork.network_profile(all_vars['network_profile'] || 'default')
    selected = profiles[profile]
    raise "NETWORK_PROFILE=#{profile.inspect} is not defined in network_profiles" unless selected.is_a?(Hash)

    expected_networks = (network_names || selected['networks'] || []).map(&:to_s).uniq
    return if expected_networks.empty?

    expected_networks.each do |network_name|
      validate_network!(all_vars['networks'] || {}, profile, network_name)
    end
  end

  def validate_network!(networks, profile_name, network_name)
    expected = networks[network_name]
    raise "NETWORK_PROFILE=#{profile_name.inspect} references unknown lab network #{network_name.inspect}" unless expected.is_a?(Hash)

    expected = expected.merge('forward_mode' => expected['forward_mode'] || 'route')

    stdout, stderr, status = Open3.capture3('virsh', 'net-dumpxml', network_name)
    unless status.success?
      raise <<~MSG
        Missing libvirt network #{network_name.inspect} for NETWORK_PROFILE=#{profile_name.inspect}.
        Run:
          NETWORK_PROFILE=#{profile_name} ansible-playbook playbooks/libvirt-host-network.yml
        virsh error:
          #{stderr.strip}
      MSG
    end

    failed = failed_checks(stdout, expected)
    return if failed.empty?

    raise <<~MSG
      Libvirt network #{network_name.inspect} exists but does not match inventory for NETWORK_PROFILE=#{profile_name.inspect}.
      Failed checks: #{failed.join(', ')}
      Expected CIDR: #{expected['cidr']}
      Run:
        NETWORK_PROFILE=#{profile_name} ansible-playbook playbooks/libvirt-host-network.yml -e libvirt_host_network_redefine=true
      Halt guests attached to #{network_name.inspect} first if needed.
    MSG
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
