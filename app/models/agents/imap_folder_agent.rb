require 'base64'
require 'delegate'
require 'net/imap'
require 'mail'

module Agents
  class ImapFolderAgent < Agent
    include FileHandling

    emits_file_pointer!

    cannot_receive_messages!

    can_dry_run!

    default_schedule 'every_30m'

    description <<-MD
      The IMAP Folder Agent checks an IMAP server in specified folders and creates Messages based on new mails found since the last run. In the first visit to a folder, this agent only checks for the initial status and does not create messages.

      Specify an IMAP server to connect with `host`, and set `ssl` to true if the server supports IMAP over SSL.  Specify `port` if you need to connect to a port other than standard (143 or 993 depending on the `ssl` value).

      Specify login credentials in `username` and `password`.

      List the names of folders to check in `folders`.

      To narrow mails by conditions, build a `conditions` hash with the following keys:

      - `subject`
      - `body`
          Specify a regular expression to match against the decoded subject/body of each mail.

          Use the `(?i)` directive for case-insensitive search.  For example, a pattern `(?i)alert` will match "alert", "Alert"or "ALERT".  You can also make only a part of a pattern to work case-insensitively: `Re: (?i:alert)` will match either "Re: Alert" or "Re: alert", but not "RE: alert".

          When a mail has multiple non-attachment text parts, they are prioritized according to the `mime_types` option (which see below) and the first part that matches a "body" pattern, if specified, will be chosen as the "body" value in a created message.

          Named captures will appear in the "matches" hash in a created message.

      - `from`, `to`, `cc`
          Specify a shell glob pattern string that is matched against mail addresses extracted from the corresponding header values of each mail.

          Patterns match addresses in case insensitive manner.

          Multiple pattern strings can be specified in an array, in which case a mail is selected if any of the patterns matches. (i.e. patterns are OR'd)

      - `mime_types`
          Specify an array of MIME types to tell which non-attachment part of a mail among its text/* parts should be used as mail body.  The default value is `['text/plain', 'text/enriched', 'text/html']`.

      - `is_unread`
          Setting this to true or false means only mails that is marked as unread or read respectively, are selected.

          If this key is unspecified or set to null, it is ignored.

      - `has_attachment`

          Setting this to true or false means only mails that does or does not have an attachment are selected.

          If this key is unspecified or set to null, it is ignored.

      Set `mark_as_read` to true to mark found mails as read.

      Set `include_attachments` to true to add a file pointer with attachment. Only one attachment is included. If an email has several attachments, only the last one will be included.

      Set `include_raw_mail` to true to add a `raw_mail` value to each created event, which contains a *Base64-encoded* blob in the "RFC822" format defined in [the IMAP4 standard](https://tools.ietf.org/html/rfc3501).

      Each agent instance memorizes the highest UID of mails that are found in the last run for each watched folder, so even if you change a set of conditions so that it matches mails that are missed previously, or if you alter the flag status of already found mails, they will not show up as new messages.

      Also, in order to avoid duplicated notification it keeps a list of Message-Id's of 100 most recent mails, so if multiple mails of the same Message-Id are found, you will only see one message out of them.
    MD

    message_description <<-MD
      Messages look like this:

          {
            "message_id": "...(Message-Id without angle brackets)...",
            "folder": "INBOX",
            "subject": "...",
            "from": "Nanashi <nanashi.gombeh@example.jp>",
            "to": ["Jane <jane.doe@example.com>"],
            "cc": [],
            "date": "2014-05-10T03:47:20+0900",
            "mime_type": "text/plain",
            "body": "Hello,\n\n...",
            "matches": {
            }
          }

      Additionally, "raw_mail" will be included if the `include_raw_mail` option is set.
    MD

    IDCACHE_SIZE = 100

    FNM_FLAGS = %i[FNM_CASEFOLD FNM_EXTGLOB].inject(0) { |flags, sym|
      if File.const_defined?(sym)
        flags | File.const_get(sym)
      else
        flags
      end
    }

    def default_options
      {
        'expected_update_period_in_days' => '1',
        'host' => 'imap.gmail.com',
        'ssl' => true,
        'username' => 'your.account',
        'password' => 'your.password',
        'folders' => %w[INBOX],
        'conditions' => {}
      }
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def validate_options
      %w[host username password].each { |key|
        options[key].is_a?(String) or
          errors.add(:base, "#{key} is required and must be a string")
      }

      if options['port'].present?
        errors.add(:base, 'port must be a positive integer') unless is_positive_integer?(options['port'])
      end

      %w[ssl mark_as_read include_raw_mail include_attachments].each { |key|
        next unless options[key].present?

        errors.add(:base, "#{key} must be a boolean value") if boolify(options[key]).nil?
      }

      case mime_types = options['mime_types']
      when nil
      when Array
        mime_types.all? { |mime_type|
          mime_type.is_a?(String) && mime_type.start_with?('text/')
        } or errors.add(:base, 'mime_types may only contain strings that match "text/*".')
        errors.add(:base, 'mime_types should not be empty') if mime_types.empty?
      else
        errors.add(:base, 'mime_types must be an array')
      end

      case folders = options['folders']
      when nil
      when Array
        folders.all? { |folder|
          folder.is_a?(String)
        } or errors.add(:base, 'folders may only contain strings')
        errors.add(:base, 'folders should not be empty') if folders.empty?
      else
        errors.add(:base, 'folders must be an array')
      end

      case conditions = options['conditions']
      when Hash
        conditions.each { |key, value|
          value.present? or next
          case key
          when 'subject', 'body'
            case value
            when String
              begin
                Regexp.new(value)
              rescue StandardError
                errors.add(:base, "conditions.#{key} contains an invalid regexp")
              end
            else
              errors.add(:base,
                         "conditions.#{key} contains a non-string object")
            end
          when 'from', 'to', 'cc'
            Array(value).each { |pattern|
              case pattern
              when String
                begin
                  glob_match?(pattern, '')
                rescue StandardError
                  errors.add(:base,
                             "conditions.#{key} contains an invalid glob pattern")
                end
              else
                errors.add(:base,
                           "conditions.#{key} contains a non-string object")
              end
            }
          when 'is_unread', 'has_attachment'
            case boolify(value)
            when true, false
            else
              errors.add(:base,
                         "conditions.#{key} must be a boolean value or null")
            end
          end
        }
      else
        errors.add(:base, 'conditions must be a hash')
      end

      return unless options['expected_update_period_in_days'].present?

      errors.add(:base, 'Invalid expected_update_period_in_days format') unless is_positive_integer?(options['expected_update_period_in_days'])
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def check
      each_unread_mail { |mail, notified|
        message_id = mail.message_id
        body_parts = mail.body_parts(mime_types)
        matched_part = nil
        matches = {}

        interpolated['conditions'].all? { |key, value|
          case key
          when 'subject'
            value.present? or next true
            re = Regexp.new(value)
            if (m = re.match(mail.scrubbed(:subject)))
              m.names.each { |name|
                matches[name] = m[name]
              }
              true
            else
              false
            end
          when 'body'
            value.present? or next true
            re = Regexp.new(value)
            matched_part = body_parts.find { |part|
              if (m = re.match(part.scrubbed(:decoded)))
                m.names.each { |name|
                  matches[name] = m[name]
                }
                true
              else
                false
              end
            }
          when 'from', 'to', 'cc'
            value.present? or next true
            begin
              # Mail::Field really needs to define respond_to_missing?
              # so we could use try(:addresses) here.
              addresses = mail.header[key].addresses
            rescue NoMethodError
              next false
            end
            addresses.any? { |address|
              Array(value).any? { |pattern|
                glob_match?(pattern, address)
              }
            }
          when 'has_attachment'
            boolify(value) == mail.has_attachment?
          when 'is_unread'
            true # already filtered out by each_unread_mail
          else
            log("Unknown condition key ignored: #{key}")
            true
          end
        } or next

        if notified.include?(mail.message_id)
          log("Ignoring mail: #{message_id} (already notified)")
        else
          matched_part ||= body_parts.first

          if matched_part
            mime_type = matched_part.mime_type
            body = matched_part.scrubbed(:decoded)
          else
            mime_type = 'text/plain'
            body = ''
          end

          log("Emitting a message for mail: #{message_id}")

          payload = {
            'message_id' => message_id,
            'folder' => mail.folder,
            'subject' => mail.scrubbed(:subject),
            'from' => mail[:from].decoded,
            'to' => mail.to_addrs,
            'cc' => mail.cc_addrs,
            'date' => (mail.date.iso8601 rescue nil),
            'mime_type' => mime_type,
            'body' => body,
            'matches' => matches,
            'has_attachment' => mail.has_attachment?
          }

          if boolify(interpolated['include_attachments'])
            mail.attachments.each do |attachment|
              filename = attachment.filename
              payload.merge!(
                {
                  file_pointer: {
                    file: filename,
                    filename: filename,
                    agent_id: id,
                    body: Base64.encode64(attachment.decoded)
                  }
                }
              )
            end
          end

          if boolify(interpolated['include_raw_mail'])
            payload['raw_mail'] = Base64.encode64(mail.raw_mail)
          end

          create_message payload: payload

          notified << mail.message_id if mail.message_id
        end

        if boolify(interpolated['mark_as_read'])
          log 'Marking as read'
          mail.mark_as_read unless dry_run?
        end
      }
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def each_unread_mail
      host, port, ssl, username = interpolated.values_at(:host, :port, :ssl, :username)
      ssl = boolify(ssl)
      port = (Integer(port) if port.present?)

      log("Connecting to #{host}#{format(':%d', port) if port}"\
          "#{' via SSL' if ssl}")
      Client.open(host, port: port, ssl: ssl) { |imap|
        log "Logging in as #{username}"
        imap.login(username, interpolated[:password])

        # 'lastseen' keeps a hash of { uidvalidity => lastseenuid, ... }
        lastseen, seen = self.lastseen, make_seen

        # 'notified' keeps an array of message-ids of {IDCACHE_SIZE}
        # most recent notified mails.
        notified = self.notified

        interpolated['folders'].each { |folder|
          log("Selecting the folder: #{folder}")

          imap.select(Net::IMAP.encode_utf7(folder))
          uidvalidity = imap.uidvalidity

          lastseenuid = lastseen[uidvalidity]

          if lastseenuid.nil?
            maxseq = imap.responses['EXISTS'].last

            log("Recording the initial status: #{pluralize(maxseq,
                                                           'existing mail')}")

            seen[uidvalidity] = imap.fetch(maxseq, 'UID').last.attr['UID'] if maxseq > 0

            next
          end

          seen[uidvalidity] = lastseenuid
          is_unread = boolify(interpolated['conditions']['is_unread'])

          uids = imap.uid_fetch((lastseenuid + 1)..-1, 'FLAGS')
                     .each_with_object([]) { |data, ret|
            uid, flags = data.attr.values_at('UID', 'FLAGS')
            seen[uidvalidity] = uid
            next if uid <= lastseenuid

            case is_unread
            when nil, !flags.include?(:Seen)
              ret << uid
            end
          }

          log pluralize(uids.size,
                        case is_unread
                        when true
                          'new unread mail'
                        when false
                          'new read mail'
                        else
                          'new mail'
                        end)

          next if uids.empty?

          imap.uid_fetch_mails(uids).each { |mail|
            yield mail, notified
          }
        }

        self.notified = notified
        self.lastseen = seen

        save!
      }
    ensure
      log 'Connection closed'
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity

    def mime_types
      interpolated['mime_types'] || %w[text/plain text/enriched text/html]
    end

    def lastseen
      Seen.new(memory['lastseen'])
    end

    def lastseen=(value)
      memory.delete('seen') # obsolete key
      memory['lastseen'] = value
    end

    def make_seen
      Seen.new
    end

    def notified
      Notified.new(memory['notified'])
    end

    def notified=(value)
      memory['notified'] = value
    end

    private

    def is_positive_integer?(value)
      Integer(value) >= 0
    rescue ArgumentError
      false
    end

    def glob_match?(pattern, value)
      File.fnmatch?(pattern, value, FNM_FLAGS)
    end

    def pluralize(count, noun)
      format('%<count>d %<noun>s', count: count, noun: noun.pluralize(count))
    end

    class Client < ::Net::IMAP
      class << self
        def open(host, *args)
          imap = new(host, *args)
          yield imap
        ensure
          imap&.disconnect
        end
      end

      attr_reader :uidvalidity

      def select(folder)
        ret = super(@folder = folder)
        @uidvalidity = responses['UIDVALIDITY'].last
        ret
      end

      def fetch(*args)
        super || []
      end

      def uid_fetch(*args)
        super || []
      end

      def uid_fetch_mails(set)
        uid_fetch(set, 'RFC822').map { |data|
          Message.new(self, data, folder: @folder, uidvalidity: @uidvalidity)
        }
      end
    end

    class Seen < Hash
      def initialize(hash = nil)
        super()
        # Deserialize a JSON hash which keys are strings
        hash&.each { |uidvalidity, uid|
          self[uidvalidity.to_i] = uid
        }
      end

      def []=(uidvalidity, uid)
        # Update only if the new value is larger than the current value
        return unless (curr = self[uidvalidity]).nil? || curr <= uid

        super
      end
    end

    class Notified < Array
      def initialize(array = nil)
        super()
        replace(array) if array
      end

      def <<(value)
        slice!(0...-IDCACHE_SIZE) if size > IDCACHE_SIZE
        super
      end
    end

    class Message < SimpleDelegator
      DEFAULT_BODY_MIME_TYPES = %w[text/plain text/enriched text/html].freeze

      attr_reader :uid, :folder, :uidvalidity

      module Scrubbed
        def scrubbed(method)
          (@scrubbed ||= {})[method.to_sym] ||=
            __send__(method).try(:scrub) { |bytes| "<#{bytes.unpack1('H*')}>" }
        end
      end

      include Scrubbed

      def initialize(client, fetch_data, props = {})
        @client = client
        props.each { |key, value|
          instance_variable_set(:"@#{key}", value)
        }
        attr = fetch_data.attr
        @uid = attr['UID']
        super(Mail.read_from_string(attr['RFC822']))
      end

      def has_attachment?
        @has_attachment ||=
          if (data = @client.uid_fetch(@uid, 'BODYSTRUCTURE').first)
            struct_has_attachment?(data.attr['BODYSTRUCTURE'])
          else
            false
          end
      end

      def raw_mail
        @raw_mail ||=
          if (data = @client.uid_fetch(@uid, 'BODY.PEEK[]').first)
            data.attr['BODY[]']
          else
            ''
          end
      end

      def parsed
        @parsed ||= Mail.read_from_string(raw_mail)
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def body_parts(mime_types = DEFAULT_BODY_MIME_TYPES)
        mail = parsed
        if mail.multipart?
          mail.body.set_sort_order(mime_types)
          mail.body.sort_parts!
          mail.all_parts
        else
          [mail]
        end.select { |part|
          if part.multipart? || part.attachment? || !part.text? ||
             !mime_types.include?(part.mime_type)
            false
          else
            part.extend(Scrubbed)
            true
          end
        }
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def mark_as_read
        @client.uid_store(@uid, '+FLAGS', [:Seen])
      end

      private

      def struct_has_attachment?(struct)
        struct.multipart? && (
          struct.subtype == 'MIXED' ||
          struct.parts.any? { |part|
            struct_has_attachment?(part)
          }
        )
      end
    end
  end
end
