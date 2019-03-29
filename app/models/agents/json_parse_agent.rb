module Agents
  class JsonParseAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!

    description <<-MD
      The JSON Parse Agent parses a JSON string and emits the data in a new message

      `data` is the JSON to parse. Use Liquid templating to specify the JSON string.

      You can use [Liquid templating](https://shopify.github.io/liquid/) to configure this agent.

      `data_key` sets the key which contains the parsed JSON data in emitted messages
    MD

    def default_options
      {
        'data' => '{{ data }}',
        'data_key' => 'data'
      }
    end

    message_description do
      message_sample = Utils.pretty_print(
        interpolated['data_key'] => { parsed: 'object' }
      )
      "Messages will looks like this:\n\n    #{message_sample}"
    end

    form_configurable :data
    form_configurable :data_key

    def validate_options
      errors.add(:base, 'data needs to be present') if options['data'].blank?
      errors.add(:base, 'data_key needs to be present') if options['data_key'].blank?
    end

    def working?
      received_message_without_error?
    end

    def receive(incoming_messages)
      incoming_messages.each do |message|
        mo = interpolated(message)
        create_message payload: { mo['data_key'] => JSON.parse(mo['data']) }
      rescue JSON::JSONError => e
        error("Could not parse JSON: #{e.class} '#{e.message}'")
      end
    end
  end
end
