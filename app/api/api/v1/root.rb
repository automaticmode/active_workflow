module API
  module V1
    class Root < Grape::API
      version 'v1', using: :path, vendor: 'ActiveWorkflow'
      format :json
      helpers APIAuthorization

      before do
        authorize_request!
      end

      rescue_from ActiveRecord::RecordNotFound do
        error!('404 Record not found', 404)
      end

      rescue_from :all

      resource :agents do
        get '' do
          agents = current_user.agents
          present agents, with: API::V1::Entities::Agent
        end

        get ':agent_id' do
          agent = current_user.agents.find(params[:agent_id])
          present agent, with: API::V1::Entities::Agent
        end

        params do
          optional :after, type: DateTime
          optional :limit, type: Integer
        end
        get ':agent_id/messages' do
          agent = current_user.agents.find(params[:agent_id])
          messages = agent.messages
          messages = messages.where('created_at > ?', params[:after]) if params[:after]
          messages = messages.limit(params[:limit]) if params[:limit]
          present messages, with: API::V1::Entities::Message
        end
      end

      resource :messages do
        get ':message_id' do
          message = current_user.messages.find(params[:message_id])
          present message, with: API::V1::Entities::Message, with_payload: true
        end
      end

      resource :workflows do
        get '' do
          workflows = current_user.workflows
          present workflows, with: API::V1::Entities::Workflow
        end

        get ':workflow_id' do
          workflow = current_user.workflows.find(params[:workflow_id])
          present workflow, with: API::V1::Entities::Workflow, with_agents: true
        end
      end
    end
  end
end
