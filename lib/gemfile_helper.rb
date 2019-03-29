class GemfileHelper
  class << self
    def rails_env
      ENV['RAILS_ENV'] ||
        case File.basename($0)
        when 'rspec'
          'test'
        when 'rake'
          'test' if ARGV.any? { |arg| /\Aspec(?:\z|:)/ === arg }
        end || 'development'
    end

    GEM_NAME = '[A-Za-z0-9\.\-\_]+'.freeze
    GEM_OPTIONS = '(.+?)\s*(?:,\s*(.+?)){0,1}'.freeze
    GEM_SEPARATOR = '\s*(?:,|\z)'.freeze
    GEM_REGULAR_EXPRESSION = /(#{GEM_NAME})(?:\(#{GEM_OPTIONS}\)){0,1}#{GEM_SEPARATOR}/

    def parse_each_agent_gem(string)
      return unless string
      string.scan(GEM_REGULAR_EXPRESSION).each do |name, version, args|
        if version =~ /\w+:/
          args = "#{version},#{args}"
          version = nil
        end
        yield [name, version, parse_gem_args(args)].compact
      end
    end

    private

    def parse_gem_args(args)
      return nil unless args
      options = {}
      args.scan(/(\w+):\s*(.+?)#{GEM_SEPARATOR}/).each do |key, value|
        options[key.to_sym] = value
      end
      options
    end
  end
end
