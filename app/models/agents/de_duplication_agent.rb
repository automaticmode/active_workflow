module Agents
  class DeDuplicationAgent < Agent
    include FormConfigurable
    cannot_be_scheduled!

    description <<-MD
      Receives a stream of messages and remits the message if it is not a duplicate.

      `property` the value that should be used to determine the uniqueness of the message (empty to use the whole payload).

      `lookback` amount of past messages to compare the value to (0 for unlimited).

      `expected_update_period_in_days` is used to determine if the agent is working.
    MD

    message_description <<-MD
      The DeDuplicationAgent just reemits messages it received.
    MD

    def default_options
      {
        'property' => '{{value}}',
        'lookback' => 100,
        'expected_update_period_in_days' => 1
      }
    end

    form_configurable :property
    form_configurable :lookback
    form_configurable :expected_update_period_in_days

    after_initialize :initialize_memory

    def initialize_memory
      memory['properties'] ||= []
    end

    def validate_options
      unless options['lookback'].present? && options['expected_update_period_in_days'].present?
        errors.add(:base, 'The lookback and expected_update_period_in_days fields are all required.')
      end
    end

    def receive(message)
      handle(interpolated(message), message)
    end

    private

    def handle(opts, message = nil)
      property = get_hash(options['property'].blank? ? JSON.dump(message.payload) : opts['property'])
      if is_unique?(property)
        created_message = create_message payload: message.payload

        log("Propagating new message as '#{property}' is a new unique property.", inbound_message: message)
        update_memory(property, opts['lookback'].to_i)
      else
        log('Not propagating as incoming message is a duplicate.', inbound_message: message)
      end
    end

    def get_hash(property)
      if property.to_s.length > 10
        Zlib::crc32(property).to_s
      else
        property
      end
    end

    def is_unique?(property)
      !memory['properties'].include?(property)
    end

    def update_memory(property, amount)
      if amount != 0 && memory['properties'].length == amount
        memory['properties'].shift
      end
      memory['properties'].push(property)
    end
  end
end
