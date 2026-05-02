module ProviderOptions
  module_function

  ALLOWED = %w[
    cpus
    memory_mb
    cpu_mode
    nic_model
    video_type
    graphics
    memory_backing
    sync_folders
  ].freeze

  def apply_provider_options(lv, host, opts)
    return unless opts.is_a?(Hash)

    unknown = opts.keys.map(&:to_s) - ALLOWED
    raise "Host #{host}: unsupported provider keys: #{unknown.sort.join(', ')}" unless unknown.empty?

    begin
      lv.cpus = Integer(opts['cpus']) if opts.key?('cpus')
      lv.memory = Integer(opts['memory_mb']) if opts.key?('memory_mb')
      lv.cpu_mode = opts['cpu_mode'].to_s if opts.key?('cpu_mode')
      lv.nic_model_type = opts['nic_model'].to_s if opts.key?('nic_model')
      lv.video_type = opts['video_type'].to_s if opts.key?('video_type')

      if opts.key?('graphics')
        graphics = opts['graphics']
        raise "Host #{host}: provider.graphics must be a hash" unless graphics.is_a?(Hash)

        lv.graphics_type = graphics['type'].to_s if graphics.key?('type')
      end

      case (opts['memory_backing'] || 'off').to_s.downcase
      when '', 'off'
      when 'shared'
        lv.memorybacking :access, mode: 'shared'
      when 'memfd'
        lv.memorybacking :access, mode: 'shared'
        lv.memorybacking :source, type: 'memfd'
      else
        raise "Host #{host}: provider.memory_backing must be off/memfd/shared"
      end
    rescue ArgumentError, TypeError => e
      raise "#{e.class}: Host #{host}: #{e.message}, opts=#{opts.inspect}"
    end
  end

  def apply_sync_folders(vm, host, opts)
    return unless opts.is_a?(Hash)

    items = opts['sync_folders']
    return unless items.is_a?(Array)

    items.each_with_index do |sync, index|
      next unless sync.is_a?(Hash) && sync['enabled']

      type = (sync['type'] || 'disabled').to_s.downcase
      next if type == 'disabled'

      raise "Host #{host}: sync_folders[].type must be virtiofs/nfs/disabled, got: #{type}" unless %w[virtiofs nfs].include?(type)

      src = sync['host_path'].to_s.strip
      dst = sync['guest_path'].to_s.strip
      raise "Host #{host}: sync_folders[].host_path required" if src.empty?
      raise "Host #{host}: sync_folders[].guest_path required" if dst.empty?

      args = {
        id: "sync-#{host}-#{index}",
        type: type
      }
      args[:readonly] = true if sync['readonly']

      vm.vm.synced_folder src, dst, **args
    end
  end
end
