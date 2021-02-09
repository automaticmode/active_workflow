require 'rails_helper'

describe API::V1::Root do
  let(:auth_token) { JsonWebToken.encode(user_id: users(:bob).id) }
  let(:headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{auth_token}" } }

  context 'Authorization' do
    it 'permits access with the right token' do
      get '/api/v1/agents',
          headers: { 'HTTP_AUTHORIZATION' => "Bearer #{auth_token}" }
      expect(response).to have_http_status 200
    end

    it 'responds with unauthorized when token is invalid' do
      get '/api/v1/agents',
          headers: { 'HTTP_AUTHORIZATION' => 'Bearer invalid_token' }
      expect(response).to have_http_status 401
    end
  end

  context '/api/v1/agents' do
    it 'returns agents' do
      get '/api/v1/agents', headers: headers
      result = JSON.parse(response.body)
      expect(result.size).to eq 8
      expect(result).to include(include('name' => 'Site status',
                                        'disabled' => false,
                                        'messages_count' => 0,
                                        'id' => a_kind_of(Integer),
                                        'sources' => [],
                                        'type' => 'Agents::HttpStatusAgent'))
    end
  end

  context '/api/v1/agents/:agent_id' do
    let(:agent) { agents(:bob_website_agent) }

    it 'returns agent info' do
      get "/api/v1/agents/#{agent.id}", headers: headers
      result = JSON.parse(response.body)
      expect(result).to include('name' => agent.name,
                                'disabled' => agent.disabled,
                                'messages_count' => agent.messages_count,
                                'id' => agent.id,
                                'sources' => agent.sources,
                                'type' => agent.type)
    end
  end

  context '/api/v1/agents/:agent_id/messages', delayed_job: true do
    let(:agent) { agents(:bob_website_agent) }

    it 'returns messages emited by the agent' do
      message = agent.messages.first
      get "/api/v1/agents/#{agent.id}/messages", headers: headers
      result = JSON.parse(response.body)
      expect(result.size).to eq agent.messages_count
      expect(result).to \
        include(include('agent_id' => message.agent_id,
                        'created_at' => message.created_at.iso8601(3),
                        'expires_at' => message.expires_at,
                        'id' => message.id))
    end

    it 'limits numbers of messages returned' do
      agent.messages << Message.create
      get "/api/v1/agents/#{agent.id}/messages?limit=1", headers: headers
      result = JSON.parse(response.body)
      expect(result.size).to eq(1)
    end

    it 'returns only messages created after the specified date' do
      time = (agent.messages.first.created_at + 1).iso8601(4)
      new_message = Message.create(created_at: DateTime.new(9999, 1, 1))
      agent.messages << new_message
      get "/api/v1/agents/#{agent.id}/messages?after=#{time}", headers: headers
      result = JSON.parse(response.body)
      expect(result.size).to eq 1
      expect(result.first['id']).to eq new_message.id
    end
  end

  context '/api/v1/messages/:message_id' do
    let(:message) { messages(:bob_website_agent_message) }

    it 'returns message with the payload' do
      get "/api/v1/messages/#{message.id}", headers: headers
      result = JSON.parse(response.body)
      expect(result).to \
        include('agent_id' => message.agent_id,
                'created_at' => message.created_at.iso8601(3),
                'expires_at' => message.expires_at,
                'id' => message.id,
                'payload' => message.payload)
    end
  end

  context '/api/v1/workflows' do
    let(:workflow) { workflows(:bob_status) }

    it 'returns workflows' do
      get '/api/v1/workflows', headers: headers
      result = JSON.parse(response.body)
      expect(result.size).to eq 1
      expect(result).to include(include('id' => workflow.id,
                                        'name' => workflow.name,
                                        'description' => workflow.description))
    end
  end

  context '/api/v1/workflows/:workflow_id' do
    let(:workflow) { workflows(:bob_status) }

    it 'returns workflow with agents' do
      get "/api/v1/workflows/#{workflow.id}", headers: headers
      result = JSON.parse(response.body)
      expect(result).to include('id' => workflow.id,
                                'name' => workflow.name,
                                'description' => workflow.description,
                                'agents' => include(
                                  include('name' => "Bob's Site Watcher"),
                                  include('name' => 'Site status')
                                ))
    end
  end
end
