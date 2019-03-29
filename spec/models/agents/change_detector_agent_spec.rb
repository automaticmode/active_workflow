require 'rails_helper'

describe Agents::ChangeDetectorAgent do
  def create_message(output = nil)
    message = Message.new
    message.agent = agents(:jane_status_agent)
    message.payload = {
      command: 'some-command',
      output: output
    }
    message.save!

    message
  end

  before do
    @valid_params = {
      property: '{{output}}',
      expected_update_period_in_days: '1'
    }

    @checker = Agents::ChangeDetectorAgent.new(name: 'somename', options: @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe 'validation' do
    before do
      expect(@checker).to be_valid
    end

    it 'should validate presence of property' do
      @checker.options[:property] = nil
      expect(@checker).not_to be_valid
    end

    it 'should validate presence of property' do
      @checker.options[:expected_update_period_in_days] = nil
      expect(@checker).not_to be_valid
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

    it 'creates messages when new message changed' do
      @message.payload[:output] = '2014-07-01'
      @checker.receive([@message])

      message = create_message('2014-08-01')

      expect {
        @checker.receive([message])
      }.to change(Message, :count).by(1)
    end

    it 'does not create message when no change' do
      @message.payload[:output] = '2014-07-01'
      @checker.receive([@message])

      expect {
        @checker.receive([@message])
      }.to change(Message, :count).by(0)
    end
  end

  describe '#receive using last_property to track lowest value' do
    before :each do
      @message = create_message('100')
    end

    before do
      # Evaluate the output as number and detect a new lowest value
      @checker.options['property'] = '{% assign drop = last_property | minus: output %}{% if last_property == blank or drop > 0 %}{{ output | default: last_property }}{% else %}{{ last_property }}{% endif %}'
    end

    it 'creates messages when the value drops' do
      @checker.receive([@message])

      message = create_message('90')
      expect {
        @checker.receive([message])
      }.to change(Message, :count).by(1)
      expect(@checker.memory['last_property']).to eq '90'
    end

    it 'does not create message when the value does not change' do
      @checker.receive([@message])

      message = create_message('100')
      expect {
        @checker.receive([message])
      }.not_to change(Message, :count)
      expect(@checker.memory['last_property']).to eq '100'
    end

    it 'does not create message when the value rises' do
      @checker.receive([@message])

      message = create_message('110')
      expect {
        @checker.receive([message])
      }.not_to change(Message, :count)
      expect(@checker.memory['last_property']).to eq '100'
    end

    it 'does not create message when the value is blank' do
      @checker.receive([@message])

      message = create_message('')
      expect {
        @checker.receive([message])
      }.not_to change(Message, :count)
      expect(@checker.memory['last_property']).to eq '100'
    end

    it 'creates messages when memory is empty' do
      expect {
        @checker.receive([@message])
      }.to change(Message, :count).by(1)
      expect(@checker.memory['last_property']).to eq '100'
    end
  end
end
