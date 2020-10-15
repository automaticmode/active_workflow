module Agents
  class DigestAgent < Agent
    include FormConfigurable

    default_schedule '6h'

    description <<-MD
      The Digest Agent collects any Messages sent to it and emits them as a single message.

      The resulting message will have a payload message of `message`. You can use liquid templating in the `message`.

      You can use [Liquid templating](https://shopify.github.io/liquid/) to configure this agent.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Messages being received by this Agent.

      If `retained_messages` is set to 0 (the default), all received messages are cleared after a digest is sent. Set `retained_messages` to a value larger than 0 to keep a certain number of messages around on a rolling basis to re-send in future digests.

      For instance, say `retained_messages` is set to 3 and the agent has received messages `5`, `4`, and `3`. When a digest is sent, messages `5`, `4`, and `3` are retained for a future digest. After message `6` is received, the next digest will contain messages `6`, `5`, and `4`.
    MD

    message_description <<-MD
      Messages look like this:

          {
            "messages": [ message list ],
            "message": "Your message"
          }
    MD

    def default_options
      {
        'expected_receive_period_in_days' => '2',
        'message' => "{{ messages | map: 'message' | join: ',' }}",
        'retained_messages' => '0'
      }
    end

    form_configurable :message, type: :text
    form_configurable :expected_receive_period_in_days
    form_configurable :retained_messages

    def validate_options
      errors.add(:base, 'retained_messages must be 0 to 999') unless options['retained_messages'].to_i >= 0 && options['retained_messages'].to_i < 1000
    end

    def receive(message)
      memory['queue'] ||= []
      memory['queue'] << message.id
      if interpolated['retained_messages'].to_i > 0 &&
         memory['queue'].length > interpolated['retained_messages'].to_i
        memory['queue'].shift(memory['queue'].length - interpolated['retained_messages'].to_i)
      end
    end

    def check
      return unless memory['queue'] && !memory['queue'].empty?
      messages = received_messages.where(id: memory['queue']).order(id: :asc).to_a
      payload = { 'messages' => messages.map(&:payload) }
      payload['message'] = interpolated(payload)['message']
      create_message payload: payload
      memory['queue'] = [] if interpolated['retained_messages'].to_i == 0
    end
  end
end
