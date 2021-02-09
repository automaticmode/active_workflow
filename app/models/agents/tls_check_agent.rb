require 'socket'
require 'openssl'

module Agents
  class TlsCheckAgent < Agent
    display_name 'TLS Check Agent'

    default_schedule 'every_12h'

    def default_options
      {
        'url' => 'https://example.com',
        'merge': false
      }
    end

    description <<-MD
      Checks a URL and emits the certificate information for that URL.  Its main intended use is to check certificates for expiration.

      *Note*: certificate signatures are not checked against any certificate
      chain/authority, therefore TLS Check agent should only be used to
      check certificates you control.

      Specify a `url` and TLS Check Agent will produce a message with the
      validity info for that certificate. The message will include the dates
      that mark the certificate validity period. Days remaining until
      certificate expires will be returned as a separate field. Field `expired`
      will indicate if a certificate has expired.

      Provided `url` *should* include URI scheme (i.e. https) and can also
      include port (optional for https):

      ```
      https://www.example.com
      ```

      If you want to check TLS for other types of services (i.e. IMAP/SMTP) you
      can use generic 'tcp' scheme and provide service port explicitly:

      ```
      tcp://imap.example.org:993
      ```

      STARTTLS is currently not supported.

      Set option `merge` to 'true' so result is merged with incoming message
      payload.
    MD

    # TODO
    message_description <<-MD
      Messages will have the following fields:

          {
            "url": "...",
            "host": "...",
            "port": "...",
            "certificate": {
              "valid": "...", // is certificate valid?
              "expired": "..." // has certificate expired?
              "days_left": "...", // days left until expiration
              "subject": [[], [], ..],
              "issuer": [[], [], ..],
              "not_before": "...",
              "not_after": "...",
            }
          }
    MD

    def check
      check_this_url(options[:url])
    end

    def receive(message)
      interpolate_with(message) do
        check_this_url(interpolated[:url], message.payload)
      end
    end

    private

    def merge?
      options[:merge]
    end

    def days_left(cert)
      return unless cert.not_after.is_a?(Time)

      today = Time.now
      ((cert.not_after - today) / 1.day).floor
    end

    def expired?(cert)
      return unless cert.not_after.is_a?(Time)

      Time.now > cert.not_after
    end

    def valid_cert?(cert)
      return unless cert.not_after.is_a?(Time)
      return unless cert.not_before.is_a?(Time)

      now = Time.now
      (now > cert.not_before) && (now < cert.not_after)
    end

    def emit_error(payload, error)
      create_message(payload: payload.merge(error: error))
    end

    def emit_cert_info(payload, cert)
      cert_payload = {
        certificate: {
          valid: valid_cert?(cert),
          subject: cert.subject.to_a,
          issuer: cert.issuer.to_a,
          not_before: cert.not_before,
          not_after: cert.not_after,
          days_left: days_left(cert),
          expired: expired?(cert)
        }
      }
      create_message(payload: payload.merge(cert_payload))
    end

    def check_this_url(url, incoming_payload = {})
      uri = URI(url)
      host = uri.host
      port = uri.port || 443
      cert_info = get_cert_info(host, port)
      error = cert_info[:error]

      payload = { url: url, host: host, port: port }
      payload = incoming_payload.merge(payload) if merge?

      return emit_error(payload, error) if error

      emit_cert_info(payload, cert_info[:cert])
    end

    def get_cert_info(host, port)
      socket = TCPSocket.open(host, port)

      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      ssl_context.cert_store = cert_store

      ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
      ssl_socket.hostname = host
      ssl_socket.connect
    rescue SocketError => e
      error_message = "Socket error: #{e.message}"
      error(error_message)
      { error: error_message }
    rescue OpenSSL::SSL::SSLError => e
      error_message = "SSL error: #{e.message}"
      error(error_message)
      { error: error_message }
    # TODO: handle Errno::ETIMEDOUT errors explicitly? (retry?)
    # TODO: handle Errno::ECONNREFUSED errors explicitly?
    rescue StandardError => e
      error(e.message)
      { error: e.message }
    else
      { cert: ssl_socket.peer_cert }
    end
  end
end
