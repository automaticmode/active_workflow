require 'active_workflow_agent/version'

class ActiveWorkflowAgent
  class << self
    attr_accessor :branch, :remote

    def load_tasks(options = {})
      @branch = options[:branch] || 'master'
      @remote = options[:remote] || 'https://github.com/automaticmode/active_workflow'
      Rake.add_rakelib File.join(File.expand_path('../', __FILE__), 'tasks')
    end

    def load(*paths)
      paths.each do |path|
        load_paths << path
      end
    end

    def register(*paths)
      paths.each do |path|
        agent_paths << path
      end
    end

    def require!
      load_paths.each do |path|
        require path
      end
      agent_paths.each do |path|
        require path
        Agent::TYPES << "Agents::#{File.basename(path.to_s).camelize}"
      end
    end

    private

    def load_paths
      @load_paths ||= []
    end

    def agent_paths
      @agent_paths ||= []
    end
  end
end
