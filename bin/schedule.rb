#!/usr/bin/env ruby

# This process is used to maintain ActiveWorkflow's upkeep behavior,
# automatically running scheduled Agents and periodically propagating and
# expiring Messages.
# It's typically run via foreman and the included Procfile.

require_relative './pre_runner_boot'

AgentRunner.new(only: ActiveWorkflowScheduler).run
