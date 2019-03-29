require 'thor'
require 'active_workflow_agent/version'

class ActiveWorkflowAgent
  class CLI < Thor
    include Thor::Actions

    desc "new AGENT_GEM_NAME", "Create a skeleton for creating a new ActiveWorkflow agent"
    def new(name)
      require 'active_workflow_agent/cli/new'
      New.new(options, name, self).run
    end

    def self.source_root
      File.expand_path(File.join(File.dirname(__FILE__), 'templates'))
    end
  end
end
