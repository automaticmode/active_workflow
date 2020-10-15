require 'time_tracker'

module Agents
  class HttpStatusAgent < Agent
    include WebRequestConcern
    include FormConfigurable

    can_dry_run!
    can_order_created_messages!

    display_name 'HTTP Status Agent'

    default_schedule 'every_12h'

    form_configurable :url
    form_configurable :disable_redirect_follow, type: :boolean
    form_configurable :changes_only, type: :boolean
    form_configurable :headers_to_include

    description <<-MD
      The HttpStatusAgent will check a URL and emit the resulting HTTP status code with the time that it waited for a reply. Additionally, it will optionally emit the value of one or more specified headers.

      Specify a `url` and the Http Status Agent will produce a message with the HTTP status code. If you specify one or more `headers_to_include` (comma-delimited), that header or headers' value(s) will be included in the message.

      The `disable_redirect_follow` option makes the agent not to follow HTTP redirects. For example, setting this to `true` will make an agent that receives a 301 redirect to `https://www.example.com` to return a status of 301 instead of following the redirect and returning 200.

      The `changes_only` option makes the agent to report a message only when the status changes. If set to `false`, a message will be created for every check.  If set to `true`, a message will only be created when the status changes (like if your site goes from 200 to 500).
    MD

    message_description <<-MD
      Messages will have the following fields:

          {
            "url": "...",
            "status": "...",
            "elapsed_time": "...",
            "headers": {
              "...": "..."
            }
          }
    MD

    def default_options
      {
        'url' => 'https://www.example.com',
        'disable_redirect_follow' => 'true'
      }
    end

    def validate_options
      errors.add(:base, 'a URL must be specified') unless options['url'].present?
    end

    def header_array(str)
      (str || '').split(',').map(&:strip)
    end

    def check
      check_this_url interpolated[:url], header_array(interpolated[:headers_to_include])
    end

    def receive(message)
      interpolate_with(message) do
        check_this_url interpolated[:url],
                       header_array(interpolated[:headers_to_include])
      end
    end

    private

    def check_this_url(url, local_headers)
      # Track time
      measured_result = TimeTracker.track { ping(url) }

      current_status = measured_result.result ? measured_result.status.to_s : ''
      return if options['changes_only'] == 'true' && current_status == memory['last_status'].to_s

      payload = { 'url' => url, 'response_received' => false, 'elapsed_time' => measured_result.elapsed_time }

      # Deal with failures
      if measured_result.result
        final_url = boolify(interpolated['disable_redirect_follow']) ? url : measured_result.result.env.url.to_s
        payload.merge!({ 'final_url' => final_url, 'redirected' => (url != final_url), 'response_received' => true, 'status' => current_status })
        # Deal with headers
        if local_headers.present?
          header_results = local_headers.each_with_object({}) { |header, hash| hash[header] = measured_result.result.headers[header] }
          payload.merge!({ 'headers' => header_results })
        end
        create_message payload: payload
        memory['last_status'] = measured_result.status.to_s
      else
        create_message payload: payload
        memory['last_status'] = nil
      end
    end

    def ping(url)
      result = faraday.get url
      result.status > 0 ? result : nil
    rescue
      nil
    end
  end
end
