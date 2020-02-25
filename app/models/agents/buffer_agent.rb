module Agents
  class BufferAgent < Agent
    include FormConfigurable

    default_schedule 'every_12h'

    description <<-MD
      The BufferAgent stores received Messages and emits copies of them on a schedule. Use this as a buffer or queue of Messages.

      `max_messages` should be set to the maximum number of messages that you'd like to hold in the buffer. When this number is
      reached, new messages will either be ignored, or will displace the oldest message already in the buffer, depending on
      whether you set `keep` to `newest` or `oldest`.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Message.

      `max_emitted_messages` is used to limit the number of the maximum messages which should be created. If you omit this BufferAgent will create messages for every message stored in the memory.
    MD

    def default_options
      {
        'expected_receive_period_in_days' => '10',
        'max_messages' => '100',
        'keep' => 'newest',
        'max_emitted_messages' => ''
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :max_events, type: :string
    form_configurable :keep, type: :array, values: %w[newest oldest]
    form_configurable :max_emitted_messages, type: :string

    # rubocop:disable Metrics/CyclomaticComplexity
    def validate_options
      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end

      unless options['keep'].present? && options['keep'].in?(%w[newest oldest])
        errors.add(:base, "The 'keep' option is required and must be set to 'oldest' or 'newest'")
      end

      unless interpolated['max_messages'].present? &&
             interpolated['max_messages'].to_i > 0
        errors.add(:base, "The 'max_messages' option is required and must be an integer greater than 0")
      end


      if interpolated['max_emitted_messages'].present?
        unless interpolated['max_emitted_messages'].to_i > 0
          errors.add(:base, "The 'max_emitted_messages' option is optional and should be an integer greater than 0")
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def receive(message)
      memory['message_ids'] ||= []
      memory['message_ids'] << message.id
      if memory['message_ids'].length > interpolated['max_messages'].to_i
        if options['keep'] == 'newest'
          memory['message_ids'].shift
        else
          memory['message_ids'].pop
        end
      end
    end

    def check
      return unless memory['message_ids'] && !memory['message_ids'].empty?
      messages = received_messages.where(id: memory['message_ids']).reorder('messages.id asc')

      if interpolated['max_emitted_messages'].present?
        messages = messages.limit(interpolated['max_emitted_messages'].to_i)
      end

      messages.each do |message|
        create_message payload: message.payload
        memory['message_ids'].delete(message.id)
      end
    end
  end
end
