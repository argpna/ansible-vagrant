module VagrantCli
  module_function

  def extract_machine_names(argv)
    return [] if argv.length < 2

    names = []
    skip_next = false

    argv[1..].each do |arg|
      if skip_next
        skip_next = false
        next
      end

      case arg
      when '--'
        break
      when /\A--(provider|provision-with)\z/, /\A-(?:p)\z/
        skip_next = true
      when /\A-/
        next
      else
        names << arg
      end
    end

    names
  end

  def validate_network_topology?(argv)
    command = argv.find { |arg| !arg.start_with?('-') }.to_s
    %w[up reload provision resume].include?(command)
  end

  def ansible_provision?(argv)
    command = argv.find { |arg| !arg.start_with?('-') }.to_s
    return false if argv.include?('--no-provision')

    %w[up reload provision].include?(command)
  end

  def matches_selector?(name, meta, selector)
    groups = (meta['groups'] || []).map(&:downcase)
    normalized = selector.downcase
    return true if normalized == name.downcase

    if normalized.include?('/') || normalized.include?('+')
      tokens = normalized.split(/[\/+]/).reject(&:empty?)
      (tokens - groups).empty?
    else
      groups.include?(normalized)
    end
  end

  def select_targets(hosts, selectors)
    return hosts if selectors.empty?

    hosts.select do |name, meta|
      selectors.any? { |selector| matches_selector?(name, meta, selector) }
    end
  end
end
