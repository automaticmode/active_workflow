# ActiveWorkflow is designed to be a multi-User system.  Users have many Agents (and Messages created by those Agents).
class User < ApplicationRecord
  DEVISE_MODULES = [:database_authenticatable, :registerable,
                    :recoverable, :rememberable, :trackable,
                    :validatable, :lockable,
                    (ENV['REQUIRE_CONFIRMED_EMAIL'] == 'true' ? :confirmable : nil)].compact
  devise(*DEVISE_MODULES)

  # Virtual attribute for authenticating by either username or email
  # This is in addition to a real persisted field like 'username'
  attr_accessor :login

  validates :username, presence: true
  validates :username, uniqueness: { case_sensitive: false }
  validates :username, format: { with: /\A[a-zA-Z0-9_-]{3,190}\Z/, message: 'can only contain letters, numbers, underscores, and dashes, and must be between 3 and 190 characters in length.' }

  has_many :user_credentials, dependent: :destroy, inverse_of: :user
  has_many :messages, -> { order('messages.created_at desc') }, dependent: :delete_all, inverse_of: :user
  has_many :agents, -> { order('agents.created_at desc') }, dependent: :destroy, inverse_of: :user
  has_many :logs, through: :agents, class_name: 'AgentLog'
  has_many :workflows, inverse_of: :user, dependent: :destroy

  # Allow users to login via either email or username.
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if (login = conditions.delete(:login))
      where(conditions).where(['lower(username) = :value OR lower(email) = :value', { value: login.downcase }])
    else
      where(conditions)
    end.first
  end

  def active?
    !deactivated_at
  end

  def deactivate!
    User.transaction do
      agents.update_all(deactivated: true)
      update_attribute(:deactivated_at, Time.now)
    end
  end

  def activate!
    User.transaction do
      agents.update_all(deactivated: false)
      update_attribute(:deactivated_at, nil)
    end
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :deactivated_account
  end

  def undefined_agent_types
    agents.reorder('').group(:type).pluck(:type).select do |type|
      type.constantize
      false
    rescue NameError
      true
    end
  end

  def undefined_agents
    agents.where(type: undefined_agent_types).select('id, schedule, messages_count, type as undefined')
  end
end
