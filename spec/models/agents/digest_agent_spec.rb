require 'rails_helper'

describe Agents::DigestAgent do
  before do
    @checker = Agents::DigestAgent.new(name: 'something', options: { expected_receive_period_in_days: '2', retained_messages: '0', message: "{{ messages | map:'data' | join:';' }}" })
    @checker.user = users(:bob)
    @checker.save!
  end

  describe '#working?' do
    it "checks to see if the Agent has received any messages in the last 'expected_receive_period_in_days' days" do
      message = Message.new
      message.agent = agents(:bob_notifier_agent)
      message.payload = { data: 'message' }
      message.save!

      expect(@checker).not_to be_working # no messages have ever been received
      @checker.options[:expected_receive_period_in_days] = 2
      @checker.save!
      Agents::DigestAgent.async_receive @checker.id, [message.id]
      expect(@checker.reload).to be_working # Messages received
      three_days_from_now = 3.days.from_now
      stub(Time).now { three_days_from_now }
      expect(@checker).not_to be_working # too much time has passed
    end
  end
  
  describe 'validation' do
    before do
      expect(@checker).to be_valid
    end
    
    it 'should validate retained_messages' do
      @checker.options[:retained_messages] = ''
      expect(@checker).to be_valid
      @checker.options[:retained_messages] = '0'
      expect(@checker).to be_valid
      @checker.options[:retained_messages] = '10'
      expect(@checker).to be_valid
      @checker.options[:retained_messages] = '10000'
      expect(@checker).not_to be_valid
      @checker.options[:retained_messages] = '-1'
      expect(@checker).not_to be_valid
    end
  end

  describe '#receive' do
    describe 'and retained_messages is 0' do
      before { @checker.options['retained_messages'] = 0 }

      it 'retained_messages any payloads it receives' do
        message1 = Message.new
        message1.agent = agents(:bob_notifier_agent)
        message1.payload = { data: 'message1' }
        message1.save!

        message2 = Message.new
        message2.agent = agents(:bob_status_agent)
        message2.payload = { data: 'message2' }
        message2.save!

        @checker.receive([message1])
        @checker.receive([message2])
        expect(@checker.memory['queue']).to eq([message1.id, message2.id])
      end
    end

    describe 'but retained_messages is 1' do

      before { @checker.options['retained_messages'] = 1 }

      it 'retained_messages only 1 message at a time' do
        message1 = Message.new
        message1.agent = agents(:bob_notifier_agent)
        message1.payload = { data: 'message1' }
        message1.save!

        message2 = Message.new
        message2.agent = agents(:bob_status_agent)
        message2.payload = { data: 'message2' }
        message2.save!  
    
        @checker.receive([message1])
        @checker.receive([message2])
        expect(@checker.memory['queue']).to eq([message2.id])
      end
    end
      
  end

  describe '#check' do
    
    describe 'and retained_messages is 0' do
      
      before { @checker.options['retained_messages'] = 0 }
      
      it 'should emit a message' do
        expect { Agents::DigestAgent.async_check(@checker.id) }.not_to change { Message.count }

        message1 = Message.new
        message1.agent = agents(:bob_notifier_agent)
        message1.payload = { data: 'message' }
        message1.save!

        message2 = Message.new
        message2.agent = agents(:bob_status_agent)
        message2.payload = { data: 'message' }
        message2.save!

        @checker.receive([message1])
        @checker.receive([message2])
        @checker.sources << agents(:bob_notifier_agent) << agents(:bob_status_agent)
        @checker.save!

        expect { @checker.check }.to change { Message.count }.by(1)
        expect(@checker.most_recent_message.payload['messages']).to eq([message1.payload, message2.payload])
        expect(@checker.most_recent_message.payload['message']).to eq('message;message')
        expect(@checker.memory['queue']).to be_empty
      end
    end

    describe 'but retained_messages is 1' do

      before { @checker.options['retained_messages'] = 1 }

      it 'should emit a message' do
        expect { Agents::DigestAgent.async_check(@checker.id) }.not_to change { Message.count }

        message1 = Message.new
        message1.agent = agents(:bob_notifier_agent)
        message1.payload = { data: 'message' }
        message1.save!

        message2 = Message.new
        message2.agent = agents(:bob_status_agent)
        message2.payload = { data: 'message' }
        message2.save!

        @checker.receive([message1])
        @checker.receive([message2])
        @checker.sources << agents(:bob_notifier_agent) << agents(:bob_status_agent)
        @checker.save!

        expect { @checker.check }.to change { Message.count }.by(1)
        expect(@checker.most_recent_message.payload['messages']).to eq([message2.payload])
        expect(@checker.most_recent_message.payload['message']).to eq('message')
        expect(@checker.memory['queue'].length).to eq(1)
      end
    end
  end
end
