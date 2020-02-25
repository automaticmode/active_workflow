require 'rails_helper'

describe Agents::EmailDigestAgent do
  it_behaves_like EmailConcern

  def get_message_part(mail, content_type)
    mail.body.parts.find { |p| p.content_type.match content_type }.body.raw_source
  end

  before do
    @checker = Agents::EmailDigestAgent.new(name: 'something', options: { expected_receive_period_in_days: '2', subject: 'something interesting' })
    @checker.user = users(:bob)
    @checker.save!

    @checker1 = Agents::EmailDigestAgent.new(name: 'something', options: { expected_receive_period_in_days: '2', subject: 'something interesting', content_type: 'text/plain' })
    @checker1.user = users(:bob)
    @checker1.save!
  end

  after do
    ActionMailer::Base.deliveries = []
  end

  describe '#receive' do
    it 'queues any payloads it receives' do
      message1 = Message.new
      message1.agent = agents(:bob_notifier_agent)
      message1.payload = { data: 'Something you should know about' }
      message1.save!

      message2 = Message.new
      message2.agent = agents(:bob_status_agent)
      message2.payload = { data: 'Something else you should know about' }
      message2.save!

      Agents::EmailDigestAgent.async_receive(@checker.id, message1.id)
      Agents::EmailDigestAgent.async_receive(@checker.id, message2.id)
      expect(@checker.reload.memory['messages']).to match([message1.id, message2.id])
    end
  end

  describe '#check' do
    it 'should send an email' do
      Agents::EmailDigestAgent.async_check(@checker.id)
      expect(ActionMailer::Base.deliveries).to eq([])

      payloads = [
        { data: 'Something you should know about' },
        { title: 'Foo', url: 'http://google.com', bar: 2 },
        { 'message' => 'hi', :woah => 'there' },
        { 'test' => 2 }
      ]

      messages = payloads.map do |payload|
        Message.new.tap do |message|
          message.agent = agents(:bob_status_agent)
          message.payload = payload
          message.save!
        end
      end

      messages.each do |message|
        @checker.receive(message)
      end
      @checker.save!

      @checker.sources << agents(:bob_status_agent)
      Agents::DigestAgent.async_check(@checker.id)

      expect(ActionMailer::Base.deliveries.last.to).to eq(['bob@example.com'])
      expect(ActionMailer::Base.deliveries.last.subject).to eq('something interesting')
      expect(get_message_part(ActionMailer::Base.deliveries.last, /plain/).strip).to eq("Message\r\n  data: Something you should know about\r\n\r\nFoo\r\n  bar: 2\r\n  url: http://google.com\r\n\r\nhi\r\n  woah: there\r\n\r\nMessage\r\n  test: 2")
      expect(@checker.reload.memory[:messages]).to be_empty
    end

    it 'logs and re-raises mailer errors' do
      mock(SystemMailer).send_message(anything) { raise Net::SMTPAuthenticationError.new('Wrong password') }

      @checker.memory[:messages] = [1]
      @checker.save!

      expect {
        Agents::EmailDigestAgent.async_check(@checker.id)
      }.to raise_error(/Wrong password/)

      expect(@checker.reload.memory[:messages]).not_to be_empty
      expect(@checker.logs.last.message).to match(/Error sending digest mail .* Wrong password/)
    end

    it 'can receive complex messages and send them on' do
      stub_request(:any, /example.com/).to_return(body: '', status: 200)
      stub.any_instance_of(Agents::HttpStatusAgent).is_tomorrow?(anything) { true }
      @checker.sources << agents(:bob_status_agent)

      Agent.async_check(agents(:bob_status_agent).id)

      Agent.receive!
      expect(@checker.reload.memory[:messages]).not_to be_empty

      Agents::EmailDigestAgent.async_check(@checker.id)

      plain_email_text = get_message_part(ActionMailer::Base.deliveries.last, /plain/).strip
      html_email_text = get_message_part(ActionMailer::Base.deliveries.last, /html/).strip

      expect(plain_email_text).to match(/response_received/)
      expect(html_email_text).to match(/response_received/)

      expect(@checker.reload.memory[:messages]).to be_empty
    end

    it 'should send email with correct content type' do
      Agents::EmailDigestAgent.async_check(@checker1.id)
      expect(ActionMailer::Base.deliveries).to eq([])

      @checker1.memory[:messages] = [1, 2, 3, 4]
      @checker1.save!

      Agents::EmailDigestAgent.async_check(@checker1.id)
      expect(ActionMailer::Base.deliveries.last.content_type).to eq('text/plain; charset=UTF-8')
    end
  end
end
