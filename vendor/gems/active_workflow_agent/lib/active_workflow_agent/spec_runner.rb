require 'active_workflow_agent/helper'

class ActiveWorkflowAgent
  class SpecRunner
    attr_reader :gem_name

    def initialize
      @gem_name = File.basename(Dir['*.gemspec'].first, '.gemspec')
      $stdout.sync = true
    end

    def clone
      unless File.exists?('spec/active_workflow/.git')
        shell_out "git clone #{ActiveWorkflowAgent.remote} -b #{ActiveWorkflowAgent.branch} spec/active_workflow", 'Cloning active_workflow source ...'
      end
    end

    def reset
      Dir.chdir('spec/active_workflow') do
        shell_out "git fetch && git reset --hard origin/#{ActiveWorkflowAgent.branch}", 'Resetting ActiveWorkflow source ...'
      end
    end

    def patch
      Dir.chdir('spec/active_workflow') do
        open('Gemfile', 'a') do |f|
          f.puts File.read(File.join(__dir__, 'patches/gemfile_helper.rb'))
        end
      end
    end

    def bundle
      if File.exists?('.env')
        shell_out "cp .env spec/active_workflow"
      end
      Dir.chdir('spec/active_workflow') do
        if !File.exists?('.env')
          shell_out "cp .env.example .env"
        end
        shell_out "bundle install --without development production -j 4", 'Installing ruby gems ...'
      end

    end

    def database
      Dir.chdir('spec/active_workflow') do
        shell_out('bundle exec rake db:create db:migrate', 'Creating database ...')
      end
    end

    def spec
      Dir.chdir('spec/active_workflow') do
        shell_out "bundle exec rspec -r #{File.join(__dir__, 'patches/coverage.rb')} --pattern '../**/*_spec.rb' --exclude-pattern './spec/**/*_spec.rb'", 'Running specs ...', true
      end
    end

    def shell_out(command, message = nil, streaming_output = false)
      print message if message

      (status, output) = Bundler.with_clean_env do
        ENV['ADDITIONAL_GEMS'] = "#{gem_name}(path: ../../)"
        ENV['RAILS_ENV'] = 'test'
        if streaming_output
          ActiveWorkflowAgent::Helper.exec(command)
        else
          ActiveWorkflowAgent::Helper.open3(command)
        end
      end

      if status == 0
        puts "\e[32m [OK]\e[0m" if message
      else
        puts "\e[31m [FAIL]\e[0m" if message
        puts "Tried executing '#{command}'"
        puts output
        fail
      end
    end
  end
end
