# Messages are how ActiveWorkflow Agents communicate and log information about the world.  Messages can be emitted and received by
# agents.  They contain a serialized `payload` of arbitrary JSON data, as well as `expires_at` fields.
class Message < ApplicationRecord
  include JSONSerializedField
  include LiquidDroppable

  json_serialize :payload

  belongs_to :user, optional: true
  belongs_to :agent, counter_cache: true

  has_many :agent_logs_as_inbound_message, class_name: 'AgentLog', foreign_key: :inbound_message_id, dependent: :nullify, inverse_of: :inbound_message
  has_many :agent_logs_as_outbound_message, class_name: 'AgentLog', foreign_key: :outbound_message_id, dependent: :nullify, inverse_of: :outbound_message

  scope :recent, lambda { |timespan = 12.hours.ago|
    where('messages.created_at > ?', timespan)
  }

  after_create :update_agent_last_message_at

  scope :expired, lambda {
    where('expires_at IS NOT NULL AND expires_at < ?', Time.now)
  }

  scope :to_expire, -> { expired }

  # Emit this message again, as a new Message.
  def reemit!
    agent.create_message payload: payload
  end

  # Look for Messages whose `expires_at` is present and in the past.  Remove those messages and then update affected Agents'
  # `messages_counts` cache columns.
  # rubocop:disable Rails/SkipsModelValidations
  def self.cleanup_expired!
    transaction do
      affected_agents = Message.expired.group('agent_id').pluck(:agent_id)
      Message.to_expire.delete_all
      Agent.where(id: affected_agents).update_all 'messages_count = (select count(*) from messages where agent_id = agents.id)'
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  protected

  # rubocop:disable Rails/SkipsModelValidations
  def update_agent_last_message_at
    agent.touch :last_message_at
  end
end

class MessageDrop
  def initialize(object)
    @payload = object.payload
    super
  end

  def liquid_method_missing(key)
    @payload[key]
  end

  def each(&block)
    @payload.each(&block)
  end

  def created_at
    @payload.fetch(__method__) { @object.created_at }
  end

  def as_json
    { agent: @object.agent.to_liquid.as_json, payload: @payload.as_json, created_at: created_at.as_json }
  end
end
