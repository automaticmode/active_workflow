require 'rails_helper'

describe Agents::JsonParseAgent do
  before(:each) do
    @checker = Agents::JsonParseAgent.new(name: 'somename', options: Agents::JsonParseAgent.new.default_options)
    @checker.user = users(:jane)
    @checker.save!
  end

  it 'message description does not throw an exception' do
    expect(@checker.message_description).to include('parsed')
  end

  describe 'validating' do
    before do
      expect(@checker).to be_valid
    end

    it 'requires data to be present' do
      @checker.options['data'] = ''
      expect(@checker).not_to be_valid
    end

    it 'requires data_key to be set' do
      @checker.options['data_key'] = ''
      expect(@checker).not_to be_valid
    end
  end

  context '#working' do
    it 'is working after receiving an message without error' do
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end
  end

  describe '#receive' do
    it 'parses valid JSON' do
      message = Message.new(payload: { data: '{"test": "data"}' })
      expect { @checker.receive([message]) }.to change(Message, :count).by(1)
    end

    it 'writes to the error log when the JSON could not be parsed' do
      message = Message.new(payload: { data: '{"test": "data}' })
      expect { @checker.receive([message]) }.to change(AgentLog, :count).by(1)
    end
  end
end
