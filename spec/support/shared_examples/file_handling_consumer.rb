require 'rails_helper'

shared_examples_for 'FileHandlingConsumer' do
  let(:message) {
    Message.new(user: @checker.user,
                payload: {
                  'file_pointer' => { 'file' => 'text.txt', 'agent_id' => @checker.id }
                })
  }

  it 'returns a file pointer' do
    expect(@checker.get_file_pointer('testfile')).to eq(file_pointer: { file: 'testfile', agent_id: @checker.id })
  end

  it 'get_io raises an exception when trying to access an agent of a different user' do
    @checker2 = @checker.dup
    @checker2.user = users(:bob)
    @checker2.save!
    message.payload['file_pointer']['agent_id'] = @checker2.id
    expect { @checker.get_io(message) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  context '#has_file_pointer?' do
    it 'returns true if the message contains a file pointer' do
      expect(@checker.has_file_pointer?(message)).to be_truthy
    end

    it 'returns false if the message does not contain a file pointer' do
      expect(@checker.has_file_pointer?(Message.new)).to be_falsy
    end
  end

  it '#get_upload_io returns a Faraday::UploadIO instance' do
    mock()
    mock(@checker).get_io(message) { StringIO.new('testdata') }

    upload_io = @checker.get_upload_io(message)
    expect(upload_io).to be_a(Faraday::UploadIO)
    expect(upload_io.content_type).to eq('text/plain')
  end
end
