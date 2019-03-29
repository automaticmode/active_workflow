module AgentControllerConcern
  extend ActiveSupport::Concern

  included do
    validate :validate_control_action
  end

  def default_options
    {
      'action' => 'run'
    }
  end

  def control_action
    interpolated['action']
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def validate_control_action
    case options['action']
    when 'run'
      control_targets.each do |target|
        if target.cannot_be_scheduled?
          errors.add(:base, "#{target.name} cannot be scheduled")
        end
      end
    when 'configure'
      if options['configure_options'].nil? || options['configure_options'].keys.empty?
        errors.add(:base, "The 'configure_options' options hash must be supplied when using the 'configure' action.")
      end
    when 'enable', 'disable'
    when nil
      errors.add(:base, 'action must be specified')
    when /\{[%{]/
      # Liquid template
    else
      errors.add(:base, 'invalid action')
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/BlockLength
  # rubocop:disable Style/RescueStandardError
  def control!
    control_targets.each do |target|
      interpolate_with('target' => target) do
        case action = control_action
        when 'run'
          if target.cannot_be_scheduled?
            error "'#{target.name}' cannot run without an incoming message"
          elsif target.disabled?
            log "Agent run ignored for disabled Agent '#{target.name}'"
          else
            Agent.async_check(target.id)
            log "Agent run queued for '#{target.name}'"
          end
        when 'enable'
          if target.disabled?
            target.update!(disabled: false)
            log "Agent '#{target.name}' is enabled"
          else
            log "Agent '#{target.name}' is already enabled"
          end
        when 'disable'
          if target.disabled?
            log "Agent '#{target.name}' is alread disabled"
          else
            target.update!(disabled: true)
            log "Agent '#{target.name}' is disabled"
          end
        when 'configure'
          target.update! options: target.options.deep_merge(interpolated['configure_options'])
          log "Agent '#{target.name}' is configured with #{interpolated['configure_options'].inspect}"
        when ''
          # Do nothing
        else
          error "Unsupported action '#{action}' ignored for '#{target.name}'"
        end
      rescue => e
        error "Failed to #{action} '#{target.name}': #{e.message}"
      end
    end
  end
  # rubocop:enable Style/RescueStandardError
  # rubocop:enable Metrics/BlockLength
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity
end
