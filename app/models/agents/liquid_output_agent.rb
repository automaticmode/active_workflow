module Agents
  class LiquidOutputAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!
    cannot_create_messages!

    DATE_UNITS = %w[second seconds minute minutes hour hours day days week weeks month months year years]

    description  do
      <<~MD
                The Liquid Output Agent outputs messages through a Liquid template you provide.  Use it to create a HTML page, or a json feed, or anything else that can be rendered as a string from your stream of ActiveWorkflow data.

                This Agent will output data at:

                `https://#{ENV['DOMAIN']}#{Rails.application.routes.url_helpers.web_requests_path(agent_id: ':id', user_id: user_id, secret: ':secret', format: :any_extension)}`

                where `:secret` is the secret specified in your options.  You can use any extension you wish.

                Options:

                  * `secret` - A token that the requestor must provide for light-weight authentication.
                  * `expected_receive_period_in_days` - How often you expect data to be received by this agent from other Agents.
                  * `content` - The content to display when someone requests this page.
                  * `mime_type` - The mime type to use when someone requests this page.
                  * `response_headers` - An object with any custom response headers. (example: `{"Access-Control-Allow-Origin": "*"}`)
                  * `mode` - The behavior that determines what data is passed to the Liquid template.
                  * `message_limit` - A limit applied to the messages passed to a template when in "Last X messages" mode. Can be a count like "1", or an amount of time like "1 day" or "5 minutes".

                # Liquid Templating

                The content you provide will be run as a Liquid template. The data from the last message received will be used when processing the Liquid template.

                More on [Liquid templating](https://shopify.github.io/liquid/).

                # Modes

                ### Merge messages

                  The data for incoming messages will be merged. So if two messages come in like this:

        ```
        { 'a' => 'b',  'c' => 'd'}
        { 'a' => 'bb', 'e' => 'f'}
        ```

                  The final result will be:

        ```
        { 'a' => 'bb', 'c' => 'd', 'e' => 'f'}
        ```

                This merged version will be passed to the Liquid template.

                ### Last message in

                  The data from the last message will be passed to the template.

                ### Last X messages

                  All of the messages received by this agent will be passed to the template
                  as the ```messages``` array.

                  The number of messages can be controlled via the ```message_limit``` option.
                  If ```message_limit``` is an integer X, the last X messages will be passed
                  to the template.  If ```message_limit``` is an integer with a unit of
                  measure like "1 day" or "5 minutes" or "9 years", a date filter will
                  be applied to the messages passed to the template.  If no ```message_limit```
                  is provided, then all of the messages for the agent will be passed to
                  the template.

                  For performance, the maximum ```message_limit``` allowed is 1000.

      MD
    end

    def default_options
      content = <<~EOF
        When you use the "Last message in" or "Merge messages" option, you can use variables from the last message received, like this:

        Name: {{name}}
        Url:  {{url}}

        If you use the "Last X Messages" mode, a set of messages will be passed to your Liquid template.  You can use them like this:

        <table class="table">
          {% for message in messages %}
            <tr>
              <td>{{ message.title }}</td>
              <td><a href="{{ message.url }}">Click here to see</a></td>
            </tr>
          {% endfor %}
        </table>
      EOF
      {
        'secret' => 'a-secret-key',
        'expected_receive_period_in_days' => 2,
        'mime_type' => 'text/html',
        'mode' => 'Last message in',
        'message_limit' => '',
        'content' => content
      }
    end

    form_configurable :secret
    form_configurable :expected_receive_period_in_days
    form_configurable :content, type: :text
    form_configurable :mime_type
    form_configurable :mode, type: :array, values: ['Last message in', 'Merge messages', 'Last X messages']
    form_configurable :message_limit

    def validate_options
      if options['secret'].present?
        case options['secret']
        when %r{[/.]}
          errors.add(:base, 'secret may not contain a slash or dot')
        when String
        else
          errors.add(:base, 'secret must be a string')
        end
      else
        errors.add(:base, "Please specify one secret for 'authenticating' incoming feed requests")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this agent is considered to be not working")
      end

      if options['message_limit'].present?
        if ((Integer(options['message_limit']) rescue false) == false)
          errors.add(:base, 'Message limit must be an integer that is less than 1001.')
        elsif (options['message_limit'].to_i > 1000)
          errors.add(:base, 'For performance reasons, you cannot have a message limit greater than 1000.')
        end
      else
      end
    end

    def receive(message)
      return unless ['merge messages', 'last message in'].include?(mode)
      memory['last_message'] ||= {}
      case mode
      when 'merge messages'
        memory['last_message'] = memory['last_message'].merge(message.payload)
      else
        memory['last_message'] = message.payload
      end
    end

    def receive_web_request(params, method, format)
      valid_authentication?(params) ? [liquified_content, 200, mime_type, interpolated['response_headers'].presence]
                                    : [unauthorized_content(format), 401]
    end

    private

    def mode
      options['mode'].to_s.downcase
    end

    def unauthorized_content(format)
      format =~ /json/ ? { error: 'Not Authorized' }
                       : 'Not Authorized'
    end

    def valid_authentication?(params)
      interpolated['secret'] == params['secret']
    end

    def mime_type
      options['mime_type'].presence || 'text/html'
    end

    def liquified_content
      interpolated(data_for_liquid_template)['content']
    end

    def data_for_liquid_template
      case mode
      when 'last x messages'
        messages = received_messages
        messages = messages.where('messages.created_at > ?', date_limit) if date_limit
        messages = messages.limit count_limit
        messages = messages.to_a.map { |x| x.payload }
        { 'messages' => messages }
      else
        memory['last_message'] || {}
      end
    end

    def count_limit
      limit = Integer(options['message_limit']) rescue 1000
      limit <= 1000 ? limit : 1000
    end

    def date_limit
      return nil unless options['message_limit'].to_s.include?(' ')
      value, unit = options['message_limit'].split(' ')
      value = Integer(value) rescue nil
      return nil unless value
      unit = unit.to_s.downcase
      return nil unless DATE_UNITS.include?(unit)
      value.send(unit.to_sym).ago
    end
  end
end
