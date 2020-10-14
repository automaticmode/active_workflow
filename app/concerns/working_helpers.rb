module WorkingHelpers
  extend ActiveSupport::Concern

  def message_created_within?(days)
    last_message_at && last_message_at > days.to_i.days.ago
  end

  def received_message_without_error?
    (last_receive_at.present? && last_error_log_at.blank?) || (last_receive_at.present? && last_error_log_at.present? && last_receive_at > last_error_log_at)
  end

  def checked_without_error?
    (last_check_at.present? && last_error_log_at.nil?) || (last_check_at.present? && last_error_log_at.present? && last_check_at > last_error_log_at)
  end

  def issue_recent_errors?
    # TODO: extract 2.minutes into env variable?
    last_message_at && last_error_log_at && last_error_log_at > (last_message_at - 2.minutes)
  end

  def issue_error_during_last_operation?
    !(received_message_without_error? || checked_without_error? || last_error_log_at.nil?)
  end

  def issue_update_timeout?
    interpolated['expected_update_period_in_days'] && !message_created_within?(interpolated['expected_update_period_in_days'])
  end

  def issue_receive_timeout?
    interpolated['expected_receive_period_in_days'] && !(last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago)
  end

  def issue_dependencies_missing?
    dependencies_missing?
  end
end
