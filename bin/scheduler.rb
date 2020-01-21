#!/usr/bin/env ruby

unless defined?(Rails)
  puts
  puts "Please run me with rails runner, for example:"
  puts "  RAILS_ENV=production bundle exec rails runner bin/#{File.basename($0)}"
  puts
  exit 1
end

require 'dotenv'

Dotenv.load if Rails.env.development?

Rails.configuration.cache_classes = true

require 'active_workflow/agent_scheduler'

agent_scheduler = ActiveWorkflow::AgentScheduler.new
agent_scheduler.run

