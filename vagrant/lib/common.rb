require 'json'
require 'open3'
require 'yaml'

module VagrantCommon
  module_function

  def env_str(key, default = nil)
    value = ENV[key]
    return default if value.nil? || value.strip.empty?

    value
  end

  def load_yaml(path)
    raise "Missing file #{path}" unless File.exist?(path)

    YAML.load_file(path) || {}
  end

  def load_group_vars(path)
    if File.directory?(path)
      Dir[File.join(path, '*.yml')].sort.each_with_object({}) do |item, out|
        out.replace(merge_hash(out, load_yaml(item)))
      end
    else
      load_yaml(path)
    end
  end

  def merge_hash(a, b)
    a = a.is_a?(Hash) ? a : {}
    b = b.is_a?(Hash) ? b : {}
    out = a.dup
    b.each do |key, value|
      if out[key].is_a?(Hash) && value.is_a?(Hash)
        out[key] = merge_hash(out[key], value)
      else
        out[key] = value
      end
    end
    out
  end

  def run_json_command(*argv, env: {})
    stdout, stderr, status = Open3.capture3(env, *argv)
    raise "Command failed: #{argv.join(' ')}\n#{stderr}" unless status.success?

    JSON.parse(stdout)
  end
end
