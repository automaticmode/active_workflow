require 'rails_helper'

shared_examples_for WorkingHelpers do
  describe '.working' do
    it 'is working before anything happens' do
      agent = described_class.new
      expect(agent).to be_working
    end

    it 'is not working if there are recent errors' do
      agent = described_class.new
      agent.last_error_log_at = 10.minutes.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent).not_to be_working
    end

    it 'is working if last check was without errors' do
      agent = described_class.new
      agent.last_error_log_at = 10.minutes.ago
      agent.last_check_at = 9.minutes.ago
      expect(agent).to be_working
    end

    it 'is working if last receive was without errors' do
      agent = described_class.new
      agent.last_error_log_at = 10.minutes.ago
      agent.last_receive_at = 9.minutes.ago
      expect(agent).to be_working
    end

    it 'is not working if no message created during long time' do
      agent = described_class.new
      agent.options['expected_update_period_in_days'] = 2
      agent.last_message_at = 3.days.ago
      expect(agent).not_to be_working
    end

    it 'is not working if no message received during long time' do
      agent = described_class.new
      agent.options['expected_receive_period_in_days'] = 2
      agent.last_receive_at = 3.days.ago
      expect(agent).not_to be_working
    end
  end

  describe 'recent_error_logs?' do
    it 'returns true if last_error_log_at is near last_message_at' do
      agent = described_class.new

      agent.last_error_log_at = 10.minutes.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.recent_error_logs?).to be_truthy

      agent.last_error_log_at = 11.minutes.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.recent_error_logs?).to be_truthy

      agent.last_error_log_at = 5.minutes.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.recent_error_logs?).to be_truthy

      agent.last_error_log_at = 15.minutes.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.recent_error_logs?).to be_falsey

      agent.last_error_log_at = 2.days.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.recent_error_logs?).to be_falsey
    end
  end

  describe 'received_message_without_error?' do
    before do
      @agent = described_class.new
    end

    it 'should return false until the first message was received' do
      expect(@agent.received_message_without_error?).to eq(false)
      @agent.last_receive_at = Time.now
      expect(@agent.received_message_without_error?).to eq(true)
    end

    it 'should return false when the last error occured after the last received message' do
      @agent.last_receive_at = Time.now - 1.minute
      @agent.last_error_log_at = Time.now
      expect(@agent.received_message_without_error?).to eq(false)
    end

    it 'should return true when the last received message occured after the last error' do
      @agent.last_receive_at = Time.now
      @agent.last_error_log_at = Time.now - 1.minute
      expect(@agent.received_message_without_error?).to eq(true)
    end
  end

  describe 'checked_without_error?' do
    before do
      @agent = described_class.new
    end

    it 'should return false until the first time check ran' do
      expect(@agent.checked_without_error?).to eq(false)
      @agent.last_check_at = Time.now
      expect(@agent.checked_without_error?).to eq(true)
    end

    it 'should return false when the last error occured after the check' do
      @agent.last_check_at = Time.now - 1.minute
      @agent.last_error_log_at = Time.now
      expect(@agent.checked_without_error?).to eq(false)
    end

    it 'should return true when the last check occured after the last error' do
      @agent.last_check_at = Time.now
      @agent.last_error_log_at = Time.now - 1.minute
      expect(@agent.checked_without_error?).to eq(true)
    end
  end
end
