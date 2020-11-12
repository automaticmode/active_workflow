require 'rails_helper'

describe 'TlsCheckAgent' do
  let(:url) { 'https://example.com' }

  let(:agent_options) do
    {
      url: url,
      merge: false
    }
  end

  let(:port) { 443 }

  let(:agent) do
    Agents::TlsCheckAgent.create!(
      name: SecureRandom.uuid,
      user: users(:jane),
      options: agent_options
    )
  end

  let(:socket) do
    Object.new
  end

  let(:tls_socket) do
    OpenStruct.new
  end

  let(:subject) { [['CN', 'www.example.org', 19]] }

  let(:issuer) { [['C', 'US', 19], ['O', "Let's Encrypt", 19], ['CN', "Let's Encrypt Authority X3", 19]] }

  let(:not_before) { Time.utc(2019, 9, 13, 1, 1, 0) }
  let(:not_after) { Time.utc(2020, 9, 14, 1, 1, 0) }

  let(:certificate) do
    OpenStruct.new({
                     subject: OpenSSL::X509::Name.new(subject),
                     issuer: OpenSSL::X509::Name.new(issuer),
                     not_before: not_before,
                     not_after: not_after
                   })
  end

  before do
    stub(TCPSocket).open(anything, port) { socket }
    stub(OpenSSL::SSL::SSLSocket).new(socket, anything) { tls_socket }
    stub(tls_socket).connect {}
    stub(tls_socket).peer_cert { certificate }
  end

  describe 'check' do
    it 'extracts hostname' do
      mock(TCPSocket).open('example.com', 443) { socket }
      agent.check
    end

    it 'sets hostname on tls_socket for SNI' do
      agent.check
      expect(tls_socket.hostname).to eq('example.com')
    end

    context 'explicit port' do
      let(:url) { 'https://example.com:12345' }
      let(:port) { 12_345 }
      it 'is used' do
        agent.check
      end
    end

    it 'emits certificate information' do
      Timecop.freeze(not_after - 1.day) do
        agent.check
      end
      msg = agent.messages.last
      certificate = msg.payload['certificate']
      expect(certificate).to include('subject' => subject)
      expect(certificate).to include('issuer' => issuer)
      expect(certificate).to include('not_before' => not_before.to_s)
      expect(certificate).to include('not_after' => not_after.to_s)
    end

    it 'calculated days left' do
      Timecop.freeze(not_after - 3.day) do
        agent.check
      end
      msg = agent.messages.last
      certificate = msg.payload['certificate']
      expect(certificate).to include('days_left' => 3)
    end

    context 'expiration' do
      it 'indicates if certificate has expired' do
        Timecop.freeze(not_after + 1.day) do
          agent.check
        end
        msg = agent.messages.last
        certificate = msg.payload['certificate']
        expect(certificate).to include('expired' => true)
        expect(certificate).to include('valid' => false)
      end

      it 'indicates if certificate has not expired' do
        Timecop.freeze(not_after - 1.day) do
          agent.check
        end
        msg = agent.messages.last
        certificate = msg.payload['certificate']
        expect(certificate).to include('expired' => false)
        expect(certificate).to include('valid' => true)
      end

      it 'indicates if certificate is not yet valid' do
        Timecop.freeze(not_before - 1.day) do
          agent.check
        end
        msg = agent.messages.last
        certificate = msg.payload['certificate']
        expect(certificate).to include('expired' => false)
        expect(certificate).to include('valid' => false)
      end
    end

    context 'invalid not_after' do
      let(:not_after) { nil }
      it 'handles invalid not_before/not_after fields' do
        agent.check
        msg = agent.messages.last
        certificate = msg.payload['certificate']
        expect(certificate).to include('expired' => nil)
        expect(certificate).to include('valid' => nil)
        expect(certificate).to include('days_left' => nil)
      end
    end

    it 'returns ssl error' do
      stub(tls_socket).connect { raise OpenSSL::SSL::SSLError, 'unknown' }
      agent.check
      msg = agent.messages.last
      expect(msg.payload['error']).to eq('SSL error: unknown')
    end

    it 'returns socket error' do
      stub(TCPSocket).open { raise SocketError, 'unresolved' }
      agent.check
      last_log = agent.logs.last
      expect(last_log.message).to eq('Socket error: unresolved')
    end

    it 'returns other errors' do
      stub(TCPSocket).open { raise Errno::ETIMEDOUT }
      agent.check
      last_log = agent.logs.last
      expect(last_log.message).to eq('Connection timed out')
    end

    it 'logs errors' do
      stub(tls_socket).connect { raise OpenSSL::SSL::SSLError, 'unknown' }
      agent.check
      last_log = agent.logs.last
      expect(last_log.message).to eq('SSL error: unknown')
    end
  end

  describe 'receive' do
    let(:message) do
      payload = {
        'domain': 'example',
        'other': 'some data'
      }
      manual_agent = Agents::ManualMessageAgent.create(name: 'Iemit')
      Message.new(payload: payload, agent: manual_agent)
    end

    let(:options) do
      {
        url: 'https://{{ domain }}.org',
        merge: false
      }
    end

    it 'interpolates url with message and checks' do
      agent.receive(message)
      msg = agent.messages.last
      certificate = msg.payload['certificate']
      expect(certificate).to include('subject' => subject)
    end

    it 'merges original message payload' do
      agent.options[:merge] = true
      agent.receive(message)
      msg = agent.messages.last
      expect(msg.payload).to include('other' => 'some data')
    end
  end
end
