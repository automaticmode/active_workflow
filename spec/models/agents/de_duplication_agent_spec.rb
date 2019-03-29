require 'rails_helper'

describe Agents::DeDuplicationAgent do
  def create_message(output = nil)
    message = Message.new
    message.agent = agents(:jane_status_agent)
    message.payload = {
      output: output
    }
    message.save!

    message
  end

  before do
    @valid_params = {
      property: '{{output}}',
      lookback: 3,
      expected_update_period_in_days: '1'
    }

    @checker = Agents::DeDuplicationAgent.new(name: 'somename', options: @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe 'validation' do
    before do
      expect(@checker).to be_valid
    end

    it 'should validate presence of lookback' do
      @checker.options[:lookback] = nil
      expect(@checker).not_to be_valid
    end

    it 'should validate presence of property' do
      @checker.options[:expected_update_period_in_days] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe '#initialize_memory' do
    it 'sets properties to an empty array' do
      expect(@checker.memory['properties']).to eq([])
    end

    it 'does not override an existing value' do
      @checker.memory['properties'] = [1, 2, 3]
      @checker.save
      @checker.reload
      expect(@checker.memory['properties']).to eq([1, 2, 3])
    end
  end

  describe '#working?' do
    before :each do
      # Need to create an message otherwise message_created_within? returns nil
      message = create_message
      @checker.receive([message])
    end

    it 'is when message created within :expected_update_period_in_days' do
      @checker.options[:expected_update_period_in_days] = 2
      expect(@checker).to be_working
    end

    it 'isnt when message created outside :expected_update_period_in_days' do
      @checker.options[:expected_update_period_in_days] = 2

      time_travel_to 2.days.from_now do
        expect(@checker).not_to be_working
      end
    end
  end

  describe '#receive' do
    before :each do
      @message = create_message('2014-07-01')
    end

    it 'creates messages when memory is empty' do
      @message.payload[:output] = '2014-07-01'
      expect {
        @checker.receive([@message])
      }.to change(Message, :count).by(1)
      expect(Message.last.payload[:command]).to eq(@message.payload[:command])
      expect(Message.last.payload[:output]).to eq(@message.payload[:output])
    end

    it 'creates messages when new message is unique' do
      @message.payload[:output] = '2014-07-01'
      @checker.receive([@message])

      message = create_message('2014-08-01')

      expect {
        @checker.receive([message])
      }.to change(Message, :count).by(1)
    end

    it 'does not create message when message is a duplicate' do
      @message.payload[:output] = '2014-07-01'
      @checker.receive([@message])

      expect {
        @checker.receive([@message])
      }.to change(Message, :count).by(0)
    end

    it 'should respect the lookback value' do
      3.times do |i|
        @message.payload[:output] = "2014-07-0#{i}"
        @checker.receive([@message])
      end
      @message.payload[:output] = '2014-07-05'
      expect {
        @checker.receive([@message])
      }.to change(Message, :count).by(1)
      expect(@checker.memory['properties'].length).to eq(3)
      expect(@checker.memory['properties']).to eq(['2014-07-01', '2014-07-02', '2014-07-05'])
    end

    it 'should hash the value if its longer then 10 chars' do
      @message.payload[:output] = '01234567890'
      expect {
        @checker.receive([@message])
      }.to change(Message, :count).by(1)
      expect(@checker.memory['properties'].last).to eq('2256157795')
    end

    it 'should use the whole message if :property is blank' do
      @checker.options['property'] = ''
      expect {
        @checker.receive([@message])
      }.to change(Message, :count).by(1)
      expect(@checker.memory['properties'].last).to eq('3023526198')
    end

    it 'should still work after the memory was cleared' do
      @checker.memory = {}
      @checker.save
      @checker.reload
      expect {
        @checker.receive([@message])
      }.not_to raise_error
    end
  end
end
