class Workflow < ApplicationRecord
  include HasGuid

  belongs_to :user, counter_cache: :workflow_count, inverse_of: :workflows
  has_many :workflow_memberships, dependent: :destroy, inverse_of: :workflow
  has_many :agents, through: :workflow_memberships, inverse_of: :workflows

  validates :name, presence: true
  validates :user, presence: true

  # Regex adapted from: http://stackoverflow.com/a/1636354/3130625
  COLOR_FORMAT = {
    with: /\A#(?:[0-9a-fA-F]{3}){1,2}\z/,
    allow_nil: true,
    message: 'must be a valid hex color.'
  }.freeze

  validates :tag_fg_color, format: COLOR_FORMAT
  validates :tag_bg_color, format: COLOR_FORMAT

  validate :agents_are_owned

  def destroy_with_mode(mode)
    case mode
    when 'all_agents'
      Agent.destroy(agents.pluck(:id))
    when 'unique_agents'
      Agent.destroy(unique_agent_ids)
    end

    destroy
  end

  def shared_agents
    agents.joins(:workflow_memberships)
          .group('agents.id')
          .having('count(workflow_memberships.agent_id) > 1')
  end

  def self.icons
    @icons ||= begin
      YAML.load_file(Rails.root.join('config', 'icons.yml'))
    end
  end

  private

  def unique_agent_ids
    agents.joins(:workflow_memberships)
          .group('workflow_memberships.agent_id')
          .having('count(workflow_memberships.agent_id) = 1')
          .pluck('workflow_memberships.agent_id')
  end

  def agents_are_owned
    return if agents.all? { |s| s.user == user }
    errors.add(:agents, 'must be owned by you')
  end
end
