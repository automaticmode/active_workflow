module Agents
  class EmailDigestAgent < Agent
    include EmailConcern

    default_schedule '5h'

    cannot_create_messages!

    description <<-MD
      The Email Digest Agent collects any messages sent to it and sends them all via email when scheduled. The number of
      used messages also relies on the `Message Expiration` option of the emitting agent, meaning that if messages expire before
      this agent is scheduled to run, they will not appear in the email.

      By default, the will have a `subject` and an optional `headline` before listing the messages.  If the messages'
      payloads contain a `message`, that will be highlighted, otherwise everything in
      their payloads will be shown.

      You can specify one or more `recipients` for the email, or skip the option in order to send the email to your
      account's default email address.

      You can provide a `from` address for the email, or leave it blank to default to the value of `EMAIL_FROM_ADDRESS` (`#{ENV['EMAIL_FROM_ADDRESS']}`).

      You can provide a `content_type` for the email and specify `text/plain` or `text/html` to be sent.
      If you do not specify `content_type`, then the recipient email server will determine the correct rendering.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between messages being received by this agent.
    MD

    def default_options
      {
        'subject' => 'You have some notifications!',
        'headline' => 'Your notifications:',
        'expected_receive_period_in_days' => '2'
      }
    end

    def receive(message)
      memory['messages'] ||= []
      memory['messages'] << message.id
    end

    def check
      return unless memory['messages'] && !memory['messages'].empty?
      payloads = received_messages.reorder('messages.id ASC').where(id: memory['messages']).pluck(:payload).to_a
      groups = payloads.map { |payload| present(payload) }
      recipients.each do |recipient|
        SystemMailer.send_message(
          to: recipient,
          from: interpolated['from'],
          subject: interpolated['subject'],
          headline: interpolated['headline'],
          content_type: interpolated['content_type'],
          groups: groups
        ).deliver_now

        log("Sent digest mail to #{recipient}")
      rescue StandardError => e
        error("Error sending digest mail to #{recipient}: #{e.message}")
        raise
      end
      memory['messages'] = []
    end
  end
end
