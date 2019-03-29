require 'rails_helper'

describe Agents::BufferAgent do
  let(:agent) do
    _agent = Agents::BufferAgent.new(name: 'My BufferAgent')
    _agent.options = _agent.default_options.merge('max_messages' => 2)
    _agent.user = users(:bob)
    _agent.sources << agents(:bob_website_agent)
    _agent.save!
    _agent
  end

  def create_message
    _message = Message.new(payload: { random: rand })
    _message.agent = agents(:bob_website_agent)
    _message.save!
    _message
  end

  let(:first_message) { create_message }
  let(:second_message) { create_message }
  let(:third_message) { create_message }

  describe '#working?' do
    it 'checks if messages have been received within expected receive period' do
      expect(agent).not_to be_working
      Agents::BufferAgent.async_receive agent.id, [messages(:bob_website_agent_message).id]
      expect(agent.reload).to be_working
      the_future = (agent.options[:expected_receive_period_in_days].to_i + 1).days.from_now
      stub(Time).now { the_future }
      expect(agent.reload).not_to be_working
    end
  end

  describe 'validation' do
    before do
      expect(agent).to be_valid
    end

    it 'should validate max_messages' do
      agent.options.delete('max_messages')
      expect(agent).not_to be_valid
      agent.options['max_messages'] = ''
      expect(agent).not_to be_valid
      agent.options['max_messages'] = '0'
      expect(agent).not_to be_valid
      agent.options['max_messages'] = '10'
      expect(agent).to be_valid
    end

    it 'should validate presence of expected_receive_period_in_days' do
      agent.options['expected_receive_period_in_days'] = ''
      expect(agent).not_to be_valid
      agent.options['expected_receive_period_in_days'] = 0
      expect(agent).not_to be_valid
      agent.options['expected_receive_period_in_days'] = -1
      expect(agent).not_to be_valid
    end

    it 'should validate keep' do
      agent.options.delete('keep')
      expect(agent).not_to be_valid
      agent.options['keep'] = ''
      expect(agent).not_to be_valid
      agent.options['keep'] = 'wrong'
      expect(agent).not_to be_valid
      agent.options['keep'] = 'newest'
      expect(agent).to be_valid
      agent.options['keep'] = 'oldest'
      expect(agent).to be_valid
    end
  end

  describe '#receive' do
    it 'records Messages' do
      expect(agent.memory).to be_empty
      agent.receive([first_message])
      expect(agent.memory).not_to be_empty
      agent.receive([second_message])
      expect(agent.memory['message_ids']).to eq [first_message.id, second_message.id]
    end

    it "keeps the newest when 'keep' is set to 'newest'" do
      expect(agent.options['keep']).to eq 'newest'
      agent.receive([first_message, second_message, third_message])
      expect(agent.memory['message_ids']).to eq [second_message.id, third_message.id]
    end

    it "keeps the oldest when 'keep' is set to 'oldest'" do
      agent.options['keep'] = 'oldest'
      agent.receive([first_message, second_message, third_message])
      expect(agent.memory['message_ids']).to eq [first_message.id, second_message.id]
    end
  end

  describe '#check' do
    it 're-emits Messages and clears the memory' do
      agent.receive([first_message, second_message, third_message])
      expect(agent.memory['message_ids']).to eq [second_message.id, third_message.id]

      expect {
        agent.check
      }.to change { agent.messages.count }.by(2)

      messages = agent.messages.reorder('messages.id desc')
      expect(messages.first.payload).to eq third_message.payload
      expect(messages.second.payload).to eq second_message.payload

      expect(agent.memory['message_ids']).to eq []
    end

    it 're-emits max_emitted_messages and clears just them from the memory' do
      agent.options['max_emitted_messages'] = 1
      agent.receive([first_message, second_message, third_message])
      expect(agent.memory['message_ids']).to eq [second_message.id, third_message.id]

      expect {
        agent.check
      }.to change { agent.messages.count }.by(1)

      messages = agent.messages.reorder('messages.id desc')
      expect(agent.memory['message_ids']).to eq [third_message.id]
      expect(messages.first.payload).to eq second_message.payload
    end
  end
end
