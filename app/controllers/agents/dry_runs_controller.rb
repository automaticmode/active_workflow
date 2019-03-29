module Agents
  class DryRunsController < ApplicationController
    include ActionView::Helpers::TextHelper

    def index
      @messages = if params[:agent_id]
                    current_user.agents.find_by(id: params[:agent_id]).received_messages.limit(5)
                  elsif params[:source_ids]
                    Message
                      .where(agent_id: current_user.agents.where(id: params[:source_ids]).pluck(:id))
                      .order('id DESC').limit(5)
                  else
                    []
                  end

      render layout: false
    end

    def create
      attrs = agent_params
      if (agent = current_user.agents.find_by(id: params[:agent_id]))
        # POST /agents/:id/dry_run
        if attrs.present?
          attrs = attrs.merge(memory: agent.memory)
          type = agent.type
          agent = Agent.build_for_type(type, current_user, attrs)
        end
      else
        # POST /agents/dry_run
        type = attrs.delete(:type)
        agent = Agent.build_for_type(type, current_user, attrs)
      end
      agent.name ||= '(Untitled)'

      if agent.valid?
        if (message_payload = params[:message])
          dummy_agent = Agent.build_for_type('ManualMessageAgent', current_user, name: 'Dry-Runner')
          dummy_agent.readonly!
          message = dummy_agent.messages.build(user: current_user, payload: message_payload, created_at: Time.now)
        end

        @results = agent.dry_run!(message)
      else
        @results = { messages: [], memory: [],
                     log:  [
                       "#{pluralize(agent.errors.count, 'error')} prohibited this Agent from being saved:",
                       *agent.errors.full_messages
                     ].join("\n- ") }
      end

      render layout: false
    end
  end
end
