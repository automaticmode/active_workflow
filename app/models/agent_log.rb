# AgentLogs are temporary records of agent activity, intended for debugging and error tracking.  They can be viewed
# in agents' detail pages.  AgentLogs with a `level` of 4 or greater are considered "errors" and automatically update
# agents' `last_error_log_at` column.  These are often used to determine if an agent is `working?`.
class AgentLog < ApplicationRecord
  belongs_to :agent
  belongs_to :inbound_message, class_name: 'Message', optional: true
  belongs_to :outbound_message, class_name: 'Message', optional: true

  validates :message, presence: true
  validates :level,
            numericality: { only_integer: true,
                            greater_than_or_equal_to: 0, less_than: 5 }

  before_validation :scrub_message
  before_save :truncate_message

  def self.log_for_agent(agent, message, options = {})
    Rails.logger.debug("Agent##{agent.id}: #{message}")

    log = agent.logs.create! options.merge(message: message)
    if agent.logs.count > log_length
      oldest_id_to_keep = agent.logs.limit(1).offset(log_length - 1).pluck('agent_logs.id')
      agent.logs.where('agent_logs.id < ?', oldest_id_to_keep).delete_all
    end

    # rubocop:disable Rails/SkipsModelValidations
    agent.update_column :last_error_log_at, Time.now if log.level >= 4
    # rubocop:enable Rails/SkipsModelValidations

    log
  end

  def self.log_length
    ENV['AGENT_LOG_LENGTH'].present? ? ENV['AGENT_LOG_LENGTH'].to_i : 200
  end

  protected

  def scrub_message
    if message_changed? && !message.nil?
      self.message = message.inspect unless message.is_a?(String)
      message.scrub! { |bytes| "<#{bytes.unpack1('H*')}>" }
    end
    true
  end

  def truncate_message
    self.message = message[0...10_000] if message.present?
  end
end
