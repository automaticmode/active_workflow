module Agents
  class ChangeDetectorAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      The Change Detector Agent receives a stream of messages and emits a new message when a property of the received message changes.

      `property` specifies a Liquid template that expands to the property to be watched, where you can use a variable `last_property` for the last property value.  If you want to detect a new lowest price, try this: `{% assign drop = last_property | minus: price %}{% if last_property == blank or drop > 0 %}{{ price | default: last_property }}{% else %}{{ last_property }}{% endif %}`

      `expected_update_period_in_days` is used to determine if the Agent is working.

      The resulting message will be a copy of the received message.
    MD

    message_description <<-MD
    This will change based on the source message. If you were message from the ShellCommandAgent, your outbound message might look like:

      {
        'command' => 'pwd',
        'path' => '/home/active_workflow',
        'exit_status' => '0',
        'errors' => '',
        'output' => '/home/active_workflow'
      }
    MD

    def default_options
      {
        'property' => '{{output}}',
        'expected_update_period_in_days' => 1
      }
    end

    def validate_options
      unless options['property'].present? && options['expected_update_period_in_days'].present?
        errors.add(:base, 'The property and expected_update_period_in_days fields are all required.')
      end
    end

    def receive(message)
      interpolation_context.stack do
        interpolation_context['last_property'] = last_property
        handle(interpolated(message), message)
      end
    end

    private

    def handle(opts, message = nil)
      property = opts['property']
      if has_changed?(property)
        created_message = create_message payload: message.payload

        log("Propagating new message as property has changed to #{property} from #{last_property}", outbound_message: created_message, inbound_message: message)
        update_memory(property)
      else
        log("Not propagating as incoming message has not changed from #{last_property}.", inbound_message: message)
      end
    end

    def has_changed?(property)
      property != last_property
    end

    def last_property
      self.memory['last_property']
    end

    def update_memory(property)
      self.memory['last_property'] = property
    end
  end
end
