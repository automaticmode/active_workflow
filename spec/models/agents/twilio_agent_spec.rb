require 'rails_helper'

describe Agents::TwilioAgent do
  before do
    @checker = Agents::TwilioAgent.new(name: 'somename',
                                       options: { account_sid: 'x',
                                                  auth_token: 'x',
                                                  sender_cell: 'x',
                                                  receiver_cell: '{{to}}',
                                                  server_url: 'http://somename.com:3000',
                                                  receive_text: 'true',
                                                  receive_call: 'true',
                                                  expected_receive_period_in_days: '1' })
    @checker.user = users(:bob)
    @checker.save!

    @message = Message.new
    @message.agent = agents(:bob_status_agent)
    @message.payload = { message: 'Looks like its going to rain', to: 54_321 }
    @message.save!

    @message_calls = []
    stub.any_instance_of(Twilio::REST::Messages).create { |message| @message_calls << message }
    stub.any_instance_of(Twilio::REST::Calls).create
  end

  describe '#receive' do
    it 'should make sure multiple messages are being received' do
      message1 = Message.new
      message1.agent = agents(:bob_notifier_agent)
      message1.payload = { message: 'Some message', to: 12_345 }
      message1.save!

      message2 = Message.new
      message2.agent = agents(:bob_status_agent)
      message2.payload = { message: 'Some other message', to: 987_654 }
      message2.save!

      @checker.receive([@message, message1, message2])
      expect(@message_calls).to eq([{ from: 'x', to: '54321', body: 'Looks like its going to rain' },
                                    { from: 'x', to: '12345', body: 'Some message' },
                                    { from: 'x', to: '987654', body: 'Some other message' }])
    end

    it 'should check if receive_text is working fine' do
      @checker.options[:receive_text] = 'false'
      @checker.receive([@message])
      expect(@message_calls).to be_empty
    end

    it 'should check if receive_call is working fine' do
      @checker.options[:receive_call] = 'true'
      @checker.receive([@message])
      expect(@checker.memory[:pending_calls]).not_to eq({})
    end
  end

  describe '#working?' do
    it 'checks if messages have been received within the expected receive period' do
      expect(@checker).not_to be_working # No messages received
      Agents::TwilioAgent.async_receive @checker.id, [@message.id]
      expect(@checker.reload).to be_working # Just received messages
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(@checker.reload).not_to be_working # More time has passed than the expected receive period without any new messages
    end
  end

  describe 'validation' do
    before do
      expect(@checker).to be_valid
    end

    it 'should validate presence of of account_sid' do
      @checker.options[:account_sid] = ''
      expect(@checker).not_to be_valid
    end

    it 'should validate presence of auth_token' do
      @checker.options[:auth_token] = ''
      expect(@checker).not_to be_valid
    end

    it 'should validate presence of receiver_cell' do
      @checker.options[:receiver_cell] = ''
      expect(@checker).not_to be_valid
    end

    it 'should validate presence of sender_cell' do
      @checker.options[:sender_cell] = ''
      expect(@checker).not_to be_valid
    end

    it 'should make sure filling sure filling server_url is not necessary' do
      @checker.options[:server_url] = ''
      expect(@checker).to be_valid
    end
  end
end
