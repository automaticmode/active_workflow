require 'rails_helper'

shared_examples_for WorkingHelpers do
  describe '.issues?' do
    it 'has no issues before anything happens' do
      agent = described_class.new
      agent.issue_recent_errors?
      expect(agent.issues?).to be_falsey
    end

    it 'has issues if there are recent errors' do
      agent = described_class.new
      agent.last_error_log_at = 10.minutes.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.issues?).to be_truthy
    end

    it 'has no issues if last check was without errors' do
      agent = described_class.new
      agent.last_error_log_at = 10.minutes.ago
      agent.last_check_at = 9.minutes.ago
      expect(agent.issues?).to be_falsey
    end

    it 'has no issues if last receive was without errors' do
      agent = described_class.new
      agent.last_error_log_at = 10.minutes.ago
      agent.last_receive_at = 9.minutes.ago
      expect(agent.issues?).to be_falsey
    end

    it 'has issues if no message created during long time' do
      agent = described_class.new
      agent.options['expected_update_period_in_days'] = 2
      agent.last_message_at = 3.days.ago
      expect(agent.issues?).to be_truthy
    end

    it 'has issues if no message received during long time' do
      agent = described_class.new
      agent.options['expected_receive_period_in_days'] = 2
      agent.last_receive_at = 3.days.ago
      expect(agent.issues?).to be_truthy
    end

    it 'has issues if dependencies are missing' do
      agent = Class.new(described_class).new
      agent.class.gem_dependency_check { false }
      expect(agent.issues?).to be_truthy
    end
  end

  describe 'issue_error_during_last_operation?' do
    it 'returns false if there are no errors' do
      agent = described_class.new

      agent.last_error_log_at = nil
      expect(agent.issue_error_during_last_operation?).to be_falsey
    end

    it 'returns false if there was check after the last error' do
      agent = described_class.new

      agent.last_error_log_at = 10.minutes.ago
      agent.last_check_at = 9.minutes.ago
      expect(agent.issue_error_during_last_operation?).to be_falsey
    end

    it 'returns false if there was receive after the last error' do
      agent = described_class.new

      agent.last_error_log_at = 10.minutes.ago
      agent.last_receive_at = 9.minutes.ago
      expect(agent.issue_error_during_last_operation?).to be_falsey
    end

    it 'returns true if there is no check or receive after the error' do
      agent = described_class.new

      agent.last_error_log_at = 8.minutes.ago
      agent.last_receive_at = 9.minutes.ago
      agent.last_check_at = 9.minutes.ago
      expect(agent.issue_error_during_last_operation?).to be_truthy
    end
  end

  describe 'issue_update_timeout?' do
    it 'returns false if agent has no update timeout setting' do
      agent = described_class.new
      agent.options.except('expected_update_period_in_days')

      expect(agent.issue_update_timeout?).to be_falsey
    end

    it 'returns false if it has emited message recently' do
      agent = described_class.new
      agent.options['expected_update_period_in_days'] = 5
      agent.last_message_at = 3.days.ago

      expect(agent.issue_update_timeout?).to be_falsey
    end

    it 'returns false if message was emited long time ago' do
      agent = described_class.new
      agent.options['expected_update_period_in_days'] = 5
      agent.last_message_at = 6.days.ago

      expect(agent.issue_update_timeout?).to be_truthy
    end
  end

  describe 'issue_receive_timeout?' do
    it 'returns false if agent has no receive timeout setting' do
      agent = described_class.new
      agent.options.except('expected_receive_period_in_days')

      expect(agent.issue_receive_timeout?).to be_falsey
    end

    it 'returns false if it has received message recently' do
      agent = described_class.new
      agent.options['expected_receive_period_in_days'] = 5
      agent.last_receive_at = 3.days.ago

      expect(agent.issue_receive_timeout?).to be_falsey
    end

    it 'returns false if message was received long time ago' do
      agent = described_class.new
      agent.options['expected_receive_period_in_days'] = 5
      agent.last_receive_at = 6.days.ago

      expect(agent.issue_receive_timeout?).to be_truthy
    end
  end

  describe 'issue_dependencies_missing?' do
    it 'returns true if dependency check failed' do
      agent = Class.new(described_class).new
      agent.class.gem_dependency_check { false }
      expect(agent.issues?).to be_truthy
    end
  end

  describe 'issue_recent_errors?' do
    it 'returns true if last_error_log_at is near last_message_at' do
      agent = described_class.new

      agent.last_error_log_at = 10.minutes.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.issue_recent_errors?).to be_truthy

      agent.last_error_log_at = 11.minutes.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.issue_recent_errors?).to be_truthy

      agent.last_error_log_at = 5.minutes.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.issue_recent_errors?).to be_truthy

      agent.last_error_log_at = 15.minutes.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.issue_recent_errors?).to be_falsey

      agent.last_error_log_at = 2.days.ago
      agent.last_message_at = 10.minutes.ago
      expect(agent.issue_recent_errors?).to be_falsey
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
