require 'active_workflow_agent/spec_runner'

unless defined?(Bundler)
  fail "Run the rake task with 'bundle exec rake'"
end

runner = ActiveWorkflowAgent::SpecRunner.new

desc "Setup ActiveWorkflow source, install gems and create the database"
task :prepare do
  runner.clone
  runner.reset
  runner.patch
  runner.bundle
  runner.database
end

desc "Run the Agent gem specs"
task :spec do
  runner.spec
end

task :default => [:prepare, :spec]
