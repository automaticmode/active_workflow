module Agents
  class DataOutputAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!
    cannot_create_messages!

    description do
      <<-MD
        The Data Output Agent outputs received messages as either RSS or JSON.  Use it to output a public or private stream of ActiveWorkflow data.

        This agent will output data at:

        `https://#{ENV['DOMAIN']}#{Rails.application.routes.url_helpers.web_requests_path(agent_id: ':id', user_id: user_id, secret: ':secret', format: :xml)}`

        where `:secret` is one of the allowed secrets specified in your options and the extension can be `xml` or `json`.

        You can setup multiple secrets so that you can individually authorize external systems to
        access your ActiveWorkflow data.

        Options:

          * `secrets` - An array of tokens that the requestor must provide for light-weight authentication.
          * `expected_receive_period_in_days` - How often you expect data to be received by this agent from other Agents.
          * `template` - A JSON object representing a mapping between item output keys and incoming message values.  Use Liquid to format the values.  Values of the `link`, `title`, `description` and `icon` keys will be put into the \\<channel\\> section of RSS output.  Value of the `self` key will be used as URL for this feed itself, which is useful when you serve it via reverse proxy.  The `item` key will be repeated for every Message.  The `pubDate` key for each item will have the creation time of the Message unless given.
          * `messages_to_show` - The number of messages to output in RSS or JSON. (default: `40`)
          * `ttl` - A value for the \\<ttl\\> element in RSS output. (default: `60`)
          * `ns_media` - Add [yahoo media namespace](https://en.wikipedia.org/wiki/Media_RSS) in output xml
          * `ns_itunes` - Add [itunes compatible namespace](http://lists.apple.com/archives/syndication-dev/2005/Nov/msg00002.html) in output xml
          * `rss_content_type` - Content-Type for RSS output (default: `application/rss+xml`)
          * `response_headers` - An object with any custom response headers. (example: `{"Access-Control-Allow-Origin": "*"}`)
          * `push_hubs` - Set to a list of PubSubHubbub endpoints you want to publish an update to every time this agent receives a message. (default: none)  Popular hubs include [Superfeedr](https://pubsubhubbub.superfeedr.com/) and [Google](https://pubsubhubbub.appspot.com/).  Note that publishing updates will make your feed URL known to the public, so if you want to keep it secret, set up a reverse proxy to serve your feed via a safe URL and specify it in `template.self`.

        If you'd like to output RSS tags with attributes, such as `enclosure`, use something like the following in your `template`:

            "enclosure": {
              "_attributes": {
                "url": "{{media_url}}",
                "length": "1234456789",
                "type": "audio/mpeg"
              }
            },
            "another_tag": {
              "_attributes": {
                "key": "value",
                "another_key": "another_value"
              },
              "_contents": "tag contents (can be an object for nesting)"
            }

        # Ordering messages

        #{description_messages_order('messages')}

        DataOutputAgent will select the last `messages_to_show` entries of its received messages sorted in the order specified by `messages_order`, which is defaulted to the message creation time.
        So, if you have multiple source agents that may create many messages in a run, you may want to either increase `messages_to_show` to have a larger "window", or specify the `messages_order` option to an appropriate value (like `date_published`) so messages from various sources are properly mixed in the resulted feed.

        There is also an option `messages_list_order` that only controls the order of messages listed in the final output, without attempting to maintain a total order of received messages.  It has the same format as `messages_order` and is defaulted to `#{Utils.jsonify(DEFAULT_MESSAGES_ORDER['messages_list_order'])}` so the selected messages are listed in reverse order like most popular RSS feeds list their articles.

        # Liquid Templating

        You can use [Liquid templating](https://shopify.github.io/liquid/) to configure this agent.

        In Liquid templating, the following variable is available:

        * `messages`: An array of messages being output, sorted in the given order, up to `messages_to_show` in number.  For example, if source messages contain a site title in the `site_title` key, you can refer to it in `template.title` by putting `{{messages.first.site_title}}`.

      MD
    end

    def default_options
      {
        'secrets' => ['a-secret-key'],
        'expected_receive_period_in_days' => 2,
        'template' => {
          'title' => 'XKCD comics as a feed',
          'description' => 'This is a feed of recent XKCD comics, generated by ActiveWorkflow',
          'item' => {
            'title' => '{{title}}',
            'description' => 'Secret hovertext: {{hovertext}}',
            'link' => '{{url}}'
          }
        },
        'ns_media' => 'true'
      }
    end

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def validate_options
      if options['secrets'].is_a?(Array) && !options['secrets'].empty?
        options['secrets'].each do |secret|
          case secret
          when %r{[/.]}
            errors.add(:base, 'secret may not contain a slash or dot')
          when String
          else
            errors.add(:base, 'secret must be a string')
          end
        end
      else
        errors.add(:base, "Please specify one or more secrets for 'authenticating' incoming feed requests")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this agent is considered to be not working")
      end

      unless options['template'].present? && options['template']['item'].present? && options['template']['item'].is_a?(Hash)
        errors.add(:base, 'Please provide template and template.item')
      end

      case options['push_hubs']
      when nil
      when Array
        options['push_hubs'].each do |hub|
          case hub
          when /\{/
            # Liquid templating
          when String
            begin
              URI.parse(hub)
            rescue URI::Error
              errors.add(:base, 'invalid URL found in push_hubs')
              break
            end
          else
            errors.add(:base, 'push_hubs must be an array of endpoint URLs')
            break
          end
        end
      else
        errors.add(:base, 'push_hubs must be an array')
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity

    def messages_to_show
      (interpolated['messages_to_show'].presence || 40).to_i
    end

    def feed_ttl
      (interpolated['ttl'].presence || 60).to_i
    end

    def feed_title
      interpolated['template']['title'].presence || "#{name} Message Feed"
    end

    def feed_link
      interpolated['template']['link'].presence || "https://#{ENV['DOMAIN']}"
    end

    def feed_url(options = {})
      interpolated['template']['self'].presence ||
        feed_link + Rails.application.routes.url_helpers
                         .web_requests_path(agent_id: id || ':id',
                                            user_id: user_id,
                                            secret: options[:secret],
                                            format: options[:format])
    end

    def feed_icon
      interpolated['template']['icon'].presence || feed_link + '/favicon.ico'
    end

    def itunes_icon
      return unless boolify(interpolated['ns_itunes'])
      "<itunes:image href=#{feed_icon.encode(xml: :attr)} />"
    end

    def feed_description
      interpolated['template']['description'].presence || "A feed of Messages received by the '#{name}' ActiveWorkflow Agent"
    end

    def rss_content_type
      interpolated['rss_content_type'].presence || 'application/rss+xml'
    end

    def xml_namespace
      namespaces = ['xmlns:atom="http://www.w3.org/2005/Atom"']

      if boolify(interpolated['ns_media'])
        namespaces << 'xmlns:media="http://search.yahoo.com/mrss/"'
      end
      if boolify(interpolated['ns_itunes'])
        namespaces << 'xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"'
      end
      namespaces.join(' ')
    end

    def push_hubs
      interpolated['push_hubs'].presence || []
    end

    DEFAULT_MESSAGES_ORDER = {
      'messages_order' => nil,
      'messages_list_order' => [['{{_index_}}', 'number', true]]
    }.freeze

    def messages_order(key = SortableMessages::MESSAGES_ORDER_KEY)
      super || DEFAULT_MESSAGES_ORDER[key]
    end

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def latest_messages(reload = false)
      received_messages = received_messages().reorder(id: :asc)

      messages =
        if (message_ids = memory[:message_ids]) &&
           memory[:messages_order] == messages_order &&
           memory[:messages_to_show] >= messages_to_show
          received_messages.where(id: message_ids).to_a
        else
          memory[:last_message_id] = nil
          reload = true
          []
        end

      if reload
        memory[:messages_order] = messages_order
        memory[:messages_to_show] = messages_to_show

        new_messages =
          if (last_message_id = memory[:last_message_id])
            received_messages.where(Message.arel_table[:id].gt(last_message_id)).to_a
          else
            source_ids.flat_map { |source_id|
              # dig twice as many messages as the number of
              # `messages_to_show`
              received_messages.where(agent_id: source_id)
                               .last(2 * messages_to_show)
            }.sort_by(&:id)
          end

        unless new_messages.empty?
          memory[:last_message_id] = new_messages.last.id
          messages.concat(new_messages)
        end
      end

      messages = sort_messages(messages).last(messages_to_show)

      memory[:message_ids] = messages.map(&:id) if reload

      messages
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def receive_web_request(params, _method, format)
      unless interpolated['secrets'].include?(params['secret'])
        return [{ error: 'Not Authorized' }, 401] if format.match?(/json/)
        return ['Not Authorized', 401]
      end

      source_messages = sort_messages(latest_messages(), 'messages_list_order')

      interpolate_with('messages' => source_messages) do
        items = source_messages.map do |message|
          interpolated = interpolate_options(options['template']['item'], message)
          interpolated['guid'] = { '_attributes' => { 'isPermaLink' => 'false' },
                                   '_contents' => interpolated['guid'].presence || message.id }
          date_string = interpolated['pubDate'].to_s
          date =
            begin
              Time.zone.parse(date_string) # may return nil
            rescue StandardError => e
              error "Error parsing a \"pubDate\" value \"#{date_string}\": #{e.message}"
              nil
            end || message.created_at
          interpolated['pubDate'] = date.rfc2822.to_s
          interpolated
        end

        now = Time.now

        if format.match?(/json/)
          content = {
            'title' => feed_title,
            'description' => feed_description,
            'pubDate' => now,
            'items' => simplify_item_for_json(items)
          }

          return [content, 200, 'application/json', interpolated['response_headers'].presence]
        else
          hub_links = push_hubs.map { |hub|
            <<-XML
 <atom:link rel="hub" href=#{hub.encode(xml: :attr)}/>
            XML
          }.join

          items = items_to_xml(items)

          return [<<~XML, 200, rss_content_type, interpolated['response_headers'].presence]
            <?xml version="1.0" encoding="UTF-8" ?>
            <rss version="2.0" #{xml_namespace}>
            <channel>
             <atom:link href=#{feed_url(secret: params['secret'], format: :xml).encode(xml: :attr)} rel="self" type="application/rss+xml" />
             <atom:icon>#{feed_icon.encode(xml: :text)}</atom:icon>
             #{itunes_icon}
            #{hub_links}
             <title>#{feed_title.encode(xml: :text)}</title>
             <description>#{feed_description.encode(xml: :text)}</description>
             <link>#{feed_link.encode(xml: :text)}</link>
             <lastBuildDate>#{now.rfc2822.to_s.encode(xml: :text)}</lastBuildDate>
             <pubDate>#{now.rfc2822.to_s.encode(xml: :text)}</pubDate>
             <ttl>#{feed_ttl}</ttl>
            #{items}
            </channel>
            </rss>
          XML
        end
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity

    def receive(_message)
      url = feed_url(secret: interpolated['secrets'].first, format: :xml)

      # Reload new messages and update cache
      latest_messages(true)

      push_hubs.each do |hub|
        push_to_hub(hub, url)
      end
    end

    private

    class XMLNode
      def initialize(tag_name, attributes, contents)
        @tag_name, @attributes, @contents = tag_name, attributes, contents
      end

      def to_xml(options)
        if @contents.is_a?(Hash)
          options[:builder].tag! @tag_name, @attributes do
            @contents.each { |key, value| ActiveSupport::XmlMini.to_tag(key, value, options.merge(skip_instruct: true)) }
          end
        else
          options[:builder].tag! @tag_name, @attributes, @contents
        end
      end
    end

    # rubocop:disable Metrics/PerceivedComplexity
    def simplify_item_for_xml(item)
      if item.is_a?(Hash)
        item.each.with_object({}) do |(key, value), memo|
          memo[key] = if value.is_a?(Hash)
                        if value.key?('_attributes') || value.key?('_contents')
                          XMLNode.new(key, value['_attributes'], simplify_item_for_xml(value['_contents']))
                        else
                          simplify_item_for_xml(value)
                        end
                      else
                        value
                      end
        end
      elsif item.is_a?(Array)
        item.map { |value| simplify_item_for_xml(value) }
      else
        item
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def simplify_item_for_json(item)
      if item.is_a?(Hash)
        item.each.with_object({}) do |(key, value), memo|
          if value.is_a?(Hash)
            if value.key?('_attributes') || value.key?('_contents')
              contents = if value['_contents']&.is_a?(Hash)
                           simplify_item_for_json(value['_contents'])
                         elsif value['_contents']
                           { 'contents' => value['_contents'] }
                         else
                           {}
                         end

              memo[key] = contents.merge(value['_attributes'] || {})
            else
              memo[key] = simplify_item_for_json(value)
            end
          else
            memo[key] = value
          end
        end
      elsif item.is_a?(Array)
        item.map { |value| simplify_item_for_json(value) }
      else
        item
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity

    # rubocop:disable Style/SpecialGlobalVars
    def items_to_xml(items)
      simplify_item_for_xml(items)
        .to_xml(skip_types: true, root: 'items', skip_instruct: true, indent: 1)
        .gsub(%r{
          (?<indent> ^\ + ) < (?<tagname> [^> ]+ ) > \n
          (?<children>
            (?: \k<indent> \  < \k<tagname> (?:\ [^>]*)? > [^<>]*? </ \k<tagname> > \n )+
          )
          \k<indent> </ \k<tagname> > \n
        }mx) { $~[:children].gsub(/^ /, '') } # delete redundant nesting of array elements
        .gsub(%r{
          (?<indent> ^\ + ) < [^> ]+ /> \n
        }mx, '') # delete empty elements
        .gsub(%r{^</?items>\n}, '')
    end
    # rubocop:enable Style/SpecialGlobalVars

    def push_to_hub(hub, url)
      hub_uri =
        begin
          URI.parse(hub)
        rescue URI::Error
          nil
        end

      unless hub_uri.is_a?(URI::HTTP)
        error("Invalid push endpoint: #{hub}")
        return
      end

      log("Pushing #{url} to #{hub_uri}")

      return if dry_run?

      begin
        faraday.post hub_uri, {
          'hub.mode' => 'publish',
          'hub.url' => url
        }
      rescue StandardError => e
        error("Push failed: #{e.message}")
      end
    end
  end
end
