require 'rails_helper'
require 'remote_agents'

RSpec.describe RemoteAgents do
  describe '.setup' do
    let(:url1) { 'http://localhost:1234' }
    let(:url2) { 'https://example.com/agent' }
    let(:env) { { 'REMOTE_AGENT_URL' => url1, 'REMOTE_AGENT_URL2' => url2 } }


    it 'reads urls from environment variables' do
      mock(RemoteAgents).register_agent(url1)
      mock(RemoteAgents).register_agent(url2)
      RemoteAgents.setup(env)
    end
  end

  describe '.register_agent' do
    let(:url) { 'http://example.com:1234' }
    let(:default_options) { { 'a' => 1 } }
    let(:agent_config) do
      {
        'name' => 'TestRemoteAgent',
        'display_name' => 'Test Remote Agent',
        'description' => 'Agent description',
        'default_options' => default_options
      }
    end
    let(:config_json) { { result: agent_config }.to_json }
    let!(:remote_register) { stub_request(:post, url).to_return(body: config_json) }

    it 'retrieves config from remote url' do
      RemoteAgents.register_agent(url)
      expect(remote_register).to have_been_requested
    end

    context 'proxy class' do
      before do
        RemoteAgents.register_agent(url)
      end

      let(:agent_class) { ::Agents::TestRemoteAgent }

      it 'creates proxy class with retrieved configuration' do
        expect(Object.const_defined?('::Agents::TestRemoteAgent')).to be true
      end

      it 'sets url on the proxy class' do
        expect(agent_class.remote_agent_url).to eq url
      end

      it 'sets remote agent config on the proxy class' do
        expect(agent_class.remote_agent_config).to eq(agent_config)
      end

      it 'sets default options on the proxy class' do
        expect(agent_class.new.default_options).to eq(default_options)
      end

      context RemoteAgents::Agent do
        let(:user) { users(:jane) }

        let(:agent) do
          a = agent_class.create(name: 'TestRemoteAgent', user: user)
          a.save!
          a
        end

        let(:remote_response) do
          {
            result: {
              errors: [
                'Error 1',
                'Error 2'
              ],
              logs: [
                'Log entry 1',
                'Log entry 2'
              ],
              memory: { value: 2 },
              messages: [
                { 'text' => 'Message 1' },
                { 'text' => 'Message 2' }
              ]
            }
          }
        end

        let(:remote_response_json) { remote_response.to_json }

        shared_examples 'handles_remote_agent_response' do
          it 'writes logs' do
            subject
            expect(agent.logs.pluck(:message)).to include('Log entry 1', 'Log entry 2')
          end

          it 'writes errors' do
            subject
            expect(agent.logs.where(level: 4).pluck(:message))
              .to include('Error 1', 'Error 2')
          end

          it 'updates memory if present' do
            subject
            expect(agent.memory).to eq('value' => 2)
          end

          it 'emits messages' do
            subject
            expect(agent.messages.pluck(:payload))
              .to include({ 'text' => 'Message 1' }, { 'text' => 'Message 2' })
          end
        end

        shared_examples 'sends_agent_state' do |method|
          it 'sets method correctly' do
            subject
            expect(remote.with do |req|
              JSON.parse(req.body)['method'] == method
            end).to have_been_made
          end

          it 'sends credentials' do
            subject
            user_credential = user.user_credentials.first
            expect(remote.with do |req|
              if JSON.parse(req.body)['method'] == method
                credentials = JSON.parse(req.body)['params']['credentials']
                expect(credentials).to include('name' => user_credential.credential_name,
                                               'value' => user_credential.credential_value)
              end
            end).to have_been_made
          end

          it 'sends options' do
            agent.options = { 'x' => true }
            subject
            expect(remote.with do |req|
              if JSON.parse(req.body)['method'] == method
                expect(JSON.parse(req.body)['params']['options']).to eq(agent.options)
              end
            end).to have_been_made
          end

          it 'sends memory' do
            agent.memory = { 'x' => true }
            subject
            expect(remote.with do |req|
              if JSON.parse(req.body)['method'] == method
                expect(JSON.parse(req.body)['params']['memory']).to eq({ 'x' => true })
              end
            end).to have_been_made
          end
        end

        describe 'check' do
          let!(:remote) do
            stub_request(:post, url).with do |req|
              JSON.parse(req.body)['method'] == 'check'
            end.to_return(body: remote_response_json)
          end

          let(:subject) { agent.check }

          include_examples 'sends_agent_state', 'check'

          include_examples 'handles_remote_agent_response'
        end

        describe 'receive' do
          let(:payload) { { 'text' => 'Payload' } }
          let(:message) { Message.create(payload: payload) }
          let(:subject) { agent.receive([message]) }

          let!(:remote) do
            stub_request(:post, url).with do |req|
              JSON.parse(req.body)['method'] == 'receive'
            end.to_return(body: remote_response_json)
          end

          it 'sends the message' do
            subject
            user_credential = user.user_credentials.first
            expect(remote.with do |req|
              if JSON.parse(req.body)['method'] == 'receive'
                expect(JSON.parse(req.body)['params']['message']['payload'])
                  .to eq(payload)
              end
            end).to have_been_made
          end

          include_examples 'sends_agent_state', 'receive'

          include_examples 'handles_remote_agent_response'
        end
      end
    end
  end
end
