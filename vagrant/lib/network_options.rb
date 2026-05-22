module VagrantNetworkOptions
  module_function

  def vagrant_options(host, interface)
    raise "Host #{host}: interface record required" unless interface.is_a?(Hash)

    network_name = interface['network_name'] || interface['network']
    mac = interface['mac']
    raise "Host #{host}: interface network required" if network_name.to_s.empty?
    raise "Host #{host}: interface mac required" if mac.to_s.empty?

    {
      libvirt__network_name: network_name.to_s,
      libvirt__always_destroy: false,
      mac: mac,
      type: 'dhcp'
    }
  end
end
