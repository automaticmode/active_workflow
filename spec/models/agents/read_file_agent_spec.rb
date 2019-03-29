require 'rails_helper'

describe Agents::ReadFileAgent do
  before(:each) do
    @valid_params = {
      'data_key' => 'data'
    }

    @checker = Agents::ReadFileAgent.new(name: 'somename', options: @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  it_behaves_like 'FileHandlingConsumer'

  context '#validate_options' do
    it 'is valid with the given options' do
      expect(@checker).to be_valid
    end

    it 'requires data_key to be present' do
      @checker.options['data_key'] = ''
      expect(@checker).not_to be_valid
    end
  end

  context '#working' do
    it 'is not working without having received an message' do
      expect(@checker).not_to be_working
    end

    it 'is working after receiving an message without error' do
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end
  end

  context '#receive' do
    it 'emits an message with the contents of the receives files' do
      message = Message.new(payload: { file_pointer: { agent_id: 111, file: 'test' } })
      io_mock = mock()
      mock(@checker).get_io(message) { StringIO.new('testdata') }
      expect { @checker.receive([message]) }.to change(Message, :count).by(1)
      expect(Message.last.payload).to eq('data' => 'testdata')
    end
  end
end
