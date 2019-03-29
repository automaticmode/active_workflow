#!/usr/bin/env ruby

# This process is used to maintain ActiveWorkflow's upkeep behavior, automatically running scheduled Agents and
# periodically propagating and expiring Messages. It also running Agents that support long running
# background jobs.

require_relative './pre_runner_boot'

AgentRunner.new(except: DelayedJobWorker).run
