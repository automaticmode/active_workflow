# Agent is the core class in ActiveWorkflow, representing a configurable, schedulable, reactive system with memory that can
# be sub-classed for many different purposes.  Agents can emit messages, as well as receive them and react in many different ways.
class Agent < ApplicationRecord
  include AssignableTypes
  include MarkdownClassAttributes
  include JSONSerializedField
  include WorkingHelpers
  include LiquidInterpolatable
  include HasGuid
  include LiquidDroppable
  include DryRunnable
  include SortableMessages

  markdown_class_attributes :description, :message_description

  load_types_in 'Agents'

  SCHEDULES = %w[every_1m every_2m every_5m every_10m every_30m
                 every_1h every_2h every_5h every_12h every_1d every_2d every_7d
                 midnight 1h 2h 3h 4h 5h 6h 7h 8h 9h 10h 11h 12h
                 13h 14h 15h 16h 17h 18h 19h 20h 21h 22h 23h never].freeze

  MESSAGE_RETENTION_SCHEDULES = [
    ['Never', 0], ['1 hour', 1.hour], ['6 hours', 6.hours], ['1 day', 1.day],
    *([2, 3, 4, 5, 7, 14, 21, 30, 45, 90, 180, 365]
      .map { |n| ["#{n} days", n.days] })
  ].freeze

  json_serialize :options, :memory

  validates :name, presence: true
  validates :user, presence: true
  validates :keep_messages_for,
            inclusion: { in: MESSAGE_RETENTION_SCHEDULES.map(&:last) }
  validates :sources, owned_by: :user_id
  validates :receivers, owned_by: :user_id
  validates :controllers, owned_by: :user_id
  validates :control_targets, owned_by: :user_id
  validates :workflows, owned_by: :user_id
  validate :validate_schedule
  validate :validate_options

  after_initialize :set_default_schedule
  before_validation :set_default_schedule
  before_validation :unschedule_if_cannot_schedule
  before_save :unschedule_if_cannot_schedule
  before_create :set_last_checked_message_id
  after_save :possibly_update_message_expirations

  belongs_to :user, inverse_of: :agents
  belongs_to :service, inverse_of: :agents, optional: true
  has_many :messages, -> { order('messages.id desc') }, dependent: :delete_all, inverse_of: :agent
  has_one  :most_recent_message, -> { order('messages.id desc') }, inverse_of: :agent, class_name: 'Message'
  has_many :logs, -> { order('agent_logs.id desc') }, dependent: :delete_all, inverse_of: :agent, class_name: 'AgentLog'
  has_many :links_as_source, dependent: :delete_all, foreign_key: 'source_id', class_name: 'Link', inverse_of: :source
  has_many :links_as_receiver, dependent: :delete_all, foreign_key: 'receiver_id', class_name: 'Link', inverse_of: :receiver
  has_many :sources, through: :links_as_receiver, class_name: 'Agent', inverse_of: :receivers
  has_many :received_messages, -> { order('messages.id desc') }, through: :sources, class_name: 'Message', source: :messages
  has_many :receivers, through: :links_as_source, class_name: 'Agent', inverse_of: :sources
  has_many :control_links_as_controller, dependent: :delete_all, foreign_key: 'controller_id', class_name: 'ControlLink', inverse_of: :controller
  has_many :control_links_as_control_target, dependent: :delete_all, foreign_key: 'control_target_id', class_name: 'ControlLink', inverse_of: :control_target
  has_many :controllers, through: :control_links_as_control_target, class_name: 'Agent', inverse_of: :control_targets
  has_many :control_targets, through: :control_links_as_controller, class_name: 'Agent', inverse_of: :controllers
  has_many :workflow_memberships, dependent: :destroy, inverse_of: :agent
  has_many :workflows, through: :workflow_memberships, inverse_of: :agents

  scope :active,   -> { where(disabled: false, deactivated: false) }
  scope :inactive, -> { where(['disabled = ? OR deactivated = ?', true, true]) }

  scope :of_type, lambda { |type|
    type = case type
           when Agent
             type.class.to_s
           else
             type.to_s
           end
    where(type: type)
  }

  def short_type
    type.demodulize
  end

  def human_type
    display_name || short_type
  end

  def check
    # Implement me in your subclass of Agent.
  end

  def default_options
    # Implement me in your subclass of Agent.
    {}
  end

  def receive(message)
    # Implement me in your subclass of Agent.
  end

  def form_configurable?
    false
  end

  def receive_web_request(_params, _method, _format)
    # Implement me in your subclass of Agent.
    ['not implemented', 404, 'text/plain', {}] # last two elements in response array are optional
  end

  # alternate method signature for receive_web_request
  # def receive_web_request(request=ActionDispatch::Request.new( ... ))
  # end

  def issues?
    issue_recent_errors? || issue_error_during_last_operation? ||
      issue_update_timeout? || issue_receive_timeout? || issue_dependencies_missing?
  end

  def build_message(message)
    message = messages.build(message) if message.is_a?(Hash)
    message.agent = self
    message.user = user
    message.expires_at ||= new_message_expiration_date
    message
  end

  def create_message(message)
    if can_create_messages?
      message = build_message(message)
      message.save!
      message
    else
      error 'This agent cannot create messages!'
    end
  end

  def credential(name)
    @credential_cache ||= {}
    if @credential_cache.key?(name)
      @credential_cache[name]
    else
      @credential_cache[name] = user.user_credentials
                                    .find_by(credential_name: name)
                                    .try(:credential_value)
    end
  end

  def reload
    @credential_cache = {}
    super
  end

  def new_message_expiration_date
    keep_messages_for > 0 ? keep_messages_for.seconds.from_now : nil
  end

  # rubocop:disable Rails/SkipsModelValidations
  def update_message_expirations!
    if keep_messages_for == 0
      messages.update_all expires_at: nil
    else
      messages.update_all "expires_at = created_at + INTERVAL '#{keep_messages_for.to_i} SECOND'"
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  def trigger_web_request(request)
    params = request.params.except(:action, :controller, :agent_id, :user_id, :format)
    handled_request = if method(:receive_web_request).arity == 1
                        receive_web_request(request)
                      else
                        receive_web_request(params, request.method_symbol.to_s, request.format.to_s)
                      end
    handled_request.tap do
      self.last_web_request_at = Time.now
      save!
    end
  end

  def unavailable?
    disabled? || dependencies_missing?
  end

  def dependencies_missing?
    self.class.dependencies_missing?
  end

  def default_schedule
    self.class.default_schedule
  end

  def display_name
    self.class.display_name
  end

  def cannot_be_scheduled?
    self.class.cannot_be_scheduled?
  end

  def can_be_scheduled?
    !cannot_be_scheduled?
  end

  def cannot_receive_messages?
    self.class.cannot_receive_messages?
  end

  def can_receive_messages?
    !cannot_receive_messages?
  end

  def cannot_create_messages?
    self.class.cannot_create_messages?
  end

  def can_create_messages?
    !cannot_create_messages?
  end

  def can_control_other_agents?
    self.class.can_control_other_agents?
  end

  def can_dry_run?
    self.class.can_dry_run?
  end

  def log(message, options = {})
    AgentLog.log_for_agent(self, message, options)
  end

  def error(message, options = {})
    log(message, options.merge(level: 4))
  end

  # rubocop:disable Rails/SkipsModelValidations
  def delete_logs!
    logs.delete_all
    update_column :last_error_log_at, nil
  end
  # rubocop:enable Rails/SkipsModelValidations

  def drop_pending_messages
    false
  end

  def drop_pending_messages=(bool)
    set_last_checked_message_id if bool
  end

  # Callbacks

  def set_default_schedule
    self.schedule = default_schedule unless schedule.present? || cannot_be_scheduled?
  end

  def unschedule_if_cannot_schedule
    self.schedule = nil if cannot_be_scheduled?
  end

  def set_last_checked_message_id
    return unless can_receive_messages? && (newest_message_id = Message.maximum(:id))
    self.last_checked_message_id = newest_message_id
  end

  def possibly_update_message_expirations
    update_message_expirations! if saved_change_to_keep_messages_for?
  end

  # Validation Methods

  private

  def validate_schedule
    return if cannot_be_scheduled?
    errors.add(:schedule, 'is not a valid schedule') unless SCHEDULES.include?(schedule.to_s)
  end

  def validate_options
    # Implement me in your subclass to test for valid options.
  end

  # Utility Methods

  def boolify(option_value)
    case option_value
    when true, 'true'
      true
    when false, 'false'
      false
    end
  end

  # Class Methods

  class << self
    def build_clone(original)
      new(original.slice(:type, :options, :service_id, :schedule, :controller_ids, :control_target_ids,
                         :source_ids, :receiver_ids, :keep_messages_for, :workflow_ids)) do |clone|
        # Give it a unique name
        2.step do |i|
          name = format('%<name>s (%<number>d)', name: original.name, number: i)
          unless exists?(name: name)
            clone.name = name
            break
          end
        end
      end
    end

    def cannot_be_scheduled!
      @cannot_be_scheduled = true
    end

    def cannot_be_scheduled?
      !!@cannot_be_scheduled
    end

    def default_schedule(schedule = nil)
      @default_schedule = schedule unless schedule.nil?
      @default_schedule
    end

    def display_name(name = nil)
      @display_name = name if name
      @display_name
    end

    def cannot_create_messages!
      @cannot_create_messages = true
    end

    def cannot_create_messages?
      !!@cannot_create_messages
    end

    def cannot_receive_messages!
      @cannot_receive_messages = true
    end

    def cannot_receive_messages?
      !!@cannot_receive_messages
    end

    def can_control_other_agents?
      include? AgentControllerConcern
    end

    def can_dry_run!
      @can_dry_run = true
    end

    def can_dry_run?
      !!@can_dry_run
    end

    def gem_dependency_check
      @gem_dependencies_checked = true
      @gem_dependencies_met = yield
    end

    def dependencies_missing?
      @gem_dependencies_checked && !@gem_dependencies_met
    end

    def async_check(agent_id)
      AgentCheckJob.perform_later(agent_id)
    end

    def async_receive(agent_id, message_id)
      AgentReceiveJob.perform_later(agent_id, message_id)
    end
  end
end

# TODO: is this used? If so - do we need it?
class AgentDrop
  def type
    @object.short_type
  end

  METHODS = %i[
    id
    name
    type
    options
    memory
    sources
    receivers
    schedule
    controllers
    control_targets
    disabled
    keep_messages_for
  ].freeze

  METHODS.each do |attr|
    define_method(attr) { @object.__send__(attr) } unless method_defined?(attr)
  end

  def url
    Rails.application.routes.url_helpers.agent_url(@object, Rails.application.config.action_mailer.default_url_options)
  end
end
