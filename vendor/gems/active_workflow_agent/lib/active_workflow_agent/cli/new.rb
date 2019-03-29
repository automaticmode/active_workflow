require 'pathname'
require 'active_workflow_agent/helper'

class ActiveWorkflowAgent
  class CLI::New
    PREFIX_QUESTION = "We recommend prefixing all ActiveWorkflow agent gem names with 'active_workflow_' to make them easily discoverable.\nPrefix gem name with 'active_workflow_'?".freeze
    MIT_QUESTION = "Do you want to license your code permissively under the MIT license?".freeze
    DOT_ENV_QUESTION = 'Which .env file do you want to use?'.freeze

    attr_reader :options, :gem_name, :thor, :target

    def initialize(options, gem_name, thor)
      @options = options
      @thor = thor
      if !gem_name.start_with?('active_workflow_') &&
         thor.yes?(PREFIX_QUESTION)
        gem_name = "active_workflow_#{gem_name}"
      end
      @target = Pathname.pwd.join(gem_name)
      @gem_name = target.basename.to_s
    end

    def run
      thor.say "Creating ActiveWorkflow agent '#{gem_name}'"

      agent_file_name = gem_name.gsub('active_workflow_', '')
      namespaced_path = gem_name.tr('-', '/')
      constant_name   = gem_name.split('_')[1..-1].map{|p| p[0..0].upcase + p[1..-1] unless p.empty?}.join
      constant_name   = constant_name.split('-').map{|q| q[0..0].upcase + q[1..-1] }.join('::') if constant_name =~ /-/
      git_user_name   = `git config user.name`.chomp
      git_user_email  = `git config user.email`.chomp

      opts = {
        :gem_name         => gem_name,
        :agent_file_name  => agent_file_name,
        :namespaced_path  => namespaced_path,
        :constant_name    => constant_name,
        :author           => git_user_name.empty? ? "TODO: Write your name" : git_user_name,
        :email            => git_user_email.empty? ? "TODO: Write your email address" : git_user_email,
      }

      templates = {
        "Gemfile.tt" => "Gemfile",
        "gitignore.tt" => ".gitignore",
        "lib/new_agent.rb.tt" => "lib/#{namespaced_path}.rb",
        "lib/new_agent/new_agent.rb.tt" => "lib/#{namespaced_path}/#{agent_file_name}.rb",
        "spec/new_agent_spec.rb.tt" => "spec/#{agent_file_name}_spec.rb",
        "newagent.gemspec.tt" => "#{gem_name}.gemspec",
        "Rakefile.tt" => "Rakefile",
        "README.md.tt" => "README.md",
        "travis.yml.tt" => ".travis.yml"
      }

      if thor.yes?(MIT_QUESTION)
        opts[:mit] = true
        templates.merge!("LICENSE.txt.tt" => "LICENSE.txt")
      end


      templates.each do |src, dst|
        thor.template("newagent/#{src}", target.join(dst), opts)
      end

      thor.say "To run the specs of your agent you need to add a .env which configures the database for ActiveWorkflow"

      possible_paths = Dir['.env', './active_workflow/.env', '~/active_workflow/.env']
      if possible_paths.length > 0
        thor.say 'Found possible preconfigured .env files please choose which one you want to use'
        possible_paths.each_with_index do |path, i|
          thor.say "#{i+1} #{path}"
        end

        if (i = thor.ask(DOT_ENV_QUESTION).to_i) != 0
          path = possible_paths[i-1]
          `cp #{path} #{target}`
          thor.say "Copied '#{path}' to '#{target}'"
        end
      end

      thor.say "Initializing git repo in #{target}"
      Dir.chdir(target) { `git init`; `git add .` }

      thor.say 'Installing dependencies'
      Dir.chdir(target) { ActiveWorkflowAgent::Helper.open3('bundle install') }
    end
  end
end
