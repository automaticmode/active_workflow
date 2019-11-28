module Agents
  class EmailAgent < Agent
    include EmailConcern

    cannot_be_scheduled!
    cannot_create_messages!
    no_bulk_receive!

    description <<-MD
      The Email Agent sends any messages it receives via email immediately.

      You can use [Liquid templating](https://shopify.github.io/liquid/) to configure this agent.

      You can specify the email's subject line by providing a `subject` option, which can contain Liquid formatting.  E.g.,
      you could provide `"ActiveWorkflow email"` to set a simple subject, or `{{subject}}` to use the `subject` key from the incoming Message.

      By default, the email body will contain an optional `headline`, followed by a listing of the Messages' keys.

      You can customize the email body by including the optional `body` param.  Like the `subject`, the `body` can be a simple message
      or a Liquid template.  You could send only the Message's `some_text` field with a `body` set to `{{ some_text }}`.
      The body can contain simple HTML and will be sanitized. Note that when using `body`, it will be wrapped with `<html>` and `<body>` tags,
      so you do not need to add these yourself.

      You can specify one or more `recipients` for the email, or skip the option in order to send the email to your
      account's default email address.

      You can provide a `from` address for the email, or leave it blank to default to the value of `EMAIL_FROM_ADDRESS` (`#{ENV['EMAIL_FROM_ADDRESS']}`).

      You can provide a `content_type` for the email and specify `text/plain` or `text/html` to be sent.
      If you do not specify `content_type`, then the recipient email server will determine the correct rendering.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Messages being received by this Agent.
    MD

    def default_options
      {
        'subject' => 'You have a notification!',
        'headline' => 'Your notification:',
        'expected_receive_period_in_days' => '2'
      }
    end

    def receive(incoming_messages)
      incoming_messages.each do |message|
        recipients(message.payload).each do |recipient|
          begin
            SystemMailer.send_message(
              to: recipient,
              from: interpolated(message)['from'],
              subject: interpolated(message)['subject'],
              headline: interpolated(message)['headline'],
              body: interpolated(message)['body'],
              content_type: interpolated(message)['content_type'],
              groups: [present(message.payload)]
            ).deliver_now
            log "Sent mail to #{recipient} with message #{message.id}"
          rescue => e
            error("Error sending mail to #{recipient} with message #{message.id}: #{e.message}")
            raise
          end
        end
      end
    end
  end
end
