module VagrantInventory
  module_function

  def flatten_resolved_hosts(ansible_inventory)
    hostvars = ansible_inventory.fetch('_meta', {}).fetch('hostvars', {})
    host_groups = host_group_memberships(ansible_inventory)

    hostvars.each_with_object({}) do |(host_name, vars_hash), out|
      interfaces = vars_hash.fetch('interfaces')
      out[host_name] = {
        'name' => host_name,
        'groups' => Array(host_groups[host_name]),
        'os' => vars_hash['os'].to_s.downcase,
        'ansible_host' => vars_hash['ansible_host'],
        'interfaces' => {
          'declared' => Array(interfaces.fetch('declared')),
          'attached' => Array(interfaces.fetch('attached')),
          'connection' => interfaces.fetch('connection'),
          'management' => interfaces['management']
        },
        'vagrant_box' => vars_hash['vagrant_box'],
        'provider_options' => vars_hash['provider_options'] || {},
        'connection' => vars_hash.select { |key, _| key.to_s.start_with?('ansible_') },
        'vars' => vars_hash
      }
    end
  end

  def host_group_memberships(ansible_inventory)
    parents = Hash.new { |hash, key| hash[key] = [] }
    direct_groups = Hash.new { |hash, key| hash[key] = [] }

    ansible_inventory.each do |group_name, group_hash|
      next if group_name == '_meta' || !group_hash.is_a?(Hash)

      Array(group_hash['children']).each do |child_name|
        parents[child_name] << group_name
      end
      Array(group_hash['hosts']).each do |host_name|
        direct_groups[host_name] << group_name
      end
    end

    direct_groups.each_with_object({}) do |(host_name, groups), out|
      out[host_name] = groups.flat_map { |group_name| [group_name] + ancestor_groups(group_name, parents) }
                             .reject { |group_name| group_name == 'all' }
                             .uniq
                             .sort
    end
  end

  def ancestor_groups(group_name, parents)
    seen = []
    stack = Array(parents[group_name])
    until stack.empty?
      parent = stack.pop
      next if seen.include?(parent)

      seen << parent
      stack.concat(Array(parents[parent]))
    end
    seen
  end
end
