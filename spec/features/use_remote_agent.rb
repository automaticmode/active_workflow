require 'rails_helper'

describe 'Using remote agent' do
  before(:all) do
    @server_thread = Thread.new do
      RemoteAgentHelper::RemoteAgent.start('localhost', 3100)
    end
    sleep 1
    RemoteAgents.setup('REMOTE_AGENT_URL' => 'http://localhost:3100')
  end

  after(:all) do
    @server_thread.terminate
  end

  before(:each) do
    login_as(user)
  end

  let(:user) { users(:bob) }
  let(:agent) do
    Agents::RemoteAgent.create(user: user, name: 'TestRemoteAgent').tap(&:save!)
  end
  let(:message) do
    Message.create(agent: agents(:jane_status_agent),
                   payload: { text: 'hello world' })
  end

  it 'creates remote agent instance', js: true do
    visit '/'
    page.find('a', text: 'Agents').click
    click_on('New Agent', match: :first)

    select_agent_type('Remote Agent')
    fill_in(:agent_name, with: 'Test Remote Agent')
    click_on 'Save'

    expect(page).to have_text('Test Remote Agent')
  end

  it "performs remote agent's check" do
    AgentCheckJob.perform_now(agent.id)
    agent.reload
    expect(agent.logs.pluck(:message)).to include('Check performed')
    expect(agent.messages.first.payload).to eq('text' => 'Remote message')
  end

  it "performs remote agent's receive" do
    AgentReceiveJob.perform_now(agent.id, message.id)
    agent.reload
    expect(agent.logs.pluck(:message)).to include('Received message hello world')
  end
end
