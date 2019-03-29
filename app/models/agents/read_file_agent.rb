module Agents
  class ReadFileAgent < Agent
    include FormConfigurable
    include FileHandling

    cannot_be_scheduled!
    consumes_file_pointer!

    def default_options
      {
        'data_key' => 'data'
      }
    end

    description do
      <<-MD
        The ReadFileAgent takes messages from `FileHandling` agents, reads the file, and emits the contents as a string.

        `data_key` specifies the key of the emitted message which contains the file contents.

        #{receiving_file_handling_agent_description}
      MD
    end

    message_description <<-MD
      {
        "data" => '...'
      }
    MD

    form_configurable :data_key, type: :string

    def validate_options
      return unless options['data_key'].blank?
      errors.add(:base, "The 'data_key' options is required.")
    end

    def working?
      received_message_without_error?
    end

    def receive(incoming_messages)
      incoming_messages.each do |message|
        next unless (io = get_io(message))
        create_message payload: { interpolated['data_key'] => io.read }
      end
    end
  end
end
