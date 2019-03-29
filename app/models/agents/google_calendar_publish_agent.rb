require 'json'
require 'google/apis/calendar_v3'

module Agents
  class GoogleCalendarPublishAgent < Agent
    cannot_be_scheduled!
    no_bulk_receive!

    gem_dependency_check { defined?(Google) && defined?(Google::Apis::CalendarV3) }

    description <<-MD
      The Google Calendar Publish Agent creates events on your Google Calendar.

      #{'## Include `google-api-client` in your Gemfile to use this Agent!' if dependencies_missing?}

      This agent relies on service accounts, rather than oauth.

      Setup:

      1. Visit [the google api console](https://code.google.com/apis/console/b/0/)
      2. New project -> ActiveWorkflow
      3. APIs & Auth -> Enable google calendar
      4. Credentials -> Create new Client ID -> Service Account
      5. Download the JSON keyfile and save it to a path, ie: `/home/active_workflow/ActiveWorkflow-5d12345678cd.json`. Or open that file and copy the `private_key`.
      6. Grant access via google calendar UI to the service account email address for each calendar you wish to manage. For a whole google apps domain, you can [delegate authority](https://developers.google.com/+/domains/authentication/delegation)

      You should generate a new JSON format keyfile, that will look something like:
      <pre><code>{
        "type": "service_account",
        "project_id": "active_workflow-123123",
        "private_key_id": "6d6b476fc6ccdb31e0f171991e5528bb396ffbe4",
        "private_key": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n",
        "client_email": "active_workflow-calendar@active_workflow-123123.iam.gserviceaccount.com",
        "client_id": "123123...123123",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://accounts.google.com/o/oauth2/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/active_workflow-calendar%40active_workflow-123123.iam.gserviceaccount.com"
      }</code></pre>


      Agent Configuration:

      `calendar_id` - The id the calendar you want to publish to. Typically your google account email address.  Liquid formatting (e.g. `{{ cal_id }}`) is allowed here in order to extract the calendar_id from the incoming message.

      `google` A hash of configuration options for the agent.

      `google` `service_account_email` - The authorised service account email address.

      `google` `key_file` OR `google` `key` - The path to the JSON key file above, or the key itself (the value of `private_key`). Liquid formatting is supported if you want to use a Credential.  (E.g., `{% credential google_key %}`)

      You can use [Liquid templating](https://shopify.github.io/liquid/) to configure this agent.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Messages being created by this Agent.

      Use it with a trigger agent to shape your payload!

      A hash of event details. See the [Google Calendar API docs](https://developers.google.com/google-apps/calendar/v3/reference/events/insert)

      The prior version Google's API expected keys like `dateTime` but in the latest version they expect snake case keys like `date_time`.

      Example payload for google calendar publishing agent:
      <pre><code>{
        "event": {
          "visibility": "default",
          "summary": "Awesome event",
          "description": "An example event with text. Pro tip: DateTimes are in RFC3339",
          "start": {
            "date_time": "2017-06-30T17:00:00-05:00"
          },
          "end": {
            "date_time": "2017-06-30T18:00:00-05:00"
          }
        }
      }</code></pre>
    MD

    message_description <<-MD
      {
        'success' => true,
        'published_calendar_event' => {
           ....
        },
        'agent_id' => 1234,
        'message_id' => 3432
      }
    MD

    def validate_options
      errors.add(:base, 'expected_update_period_in_days is required') unless options['expected_update_period_in_days'].present?
    end

    def working?
      message_created_within?(options['expected_update_period_in_days']) && most_recent_message && most_recent_message.payload['success'] == true && !recent_error_logs?
    end

    def default_options
      {
        'expected_update_period_in_days' => '10',
        'calendar_id' => 'you@email.com',
        'google' => {
          'key_file' => '/path/to/private.key',
          'key' => '-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n',
          'service_account_email' => ''
        }
      }
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def receive(incoming_messages)
      require 'google_calendar'
      incoming_messages.each do |message|
        GoogleCalendar.open(interpolate_options(options, message), Rails.logger) do |calendar|
          cal_event = message.payload['event']
          if cal_event['start'].present? && cal_event['start']['dateTime'].present? && !cal_event['start']['date_time'].present?
            cal_event['start']['date_time'] = cal_event['start'].delete 'dateTime'
          end
          if cal_event['end'].present? && cal_event['end']['dateTime'].present? && !cal_event['end']['date_time'].present?
            cal_event['end']['date_time'] = cal_event['end'].delete 'dateTime'
          end

          calendar_event = calendar.publish_as(
            interpolated(message)['calendar_id'],
            cal_event
          )

          create_message payload: {
            'success' => true,
            'published_calendar_event' => calendar_event,
            'agent_id' => message.agent_id,
            'message_id' => message.id
          }
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
  end
end
