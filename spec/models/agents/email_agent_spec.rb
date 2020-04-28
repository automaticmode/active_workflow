require 'rails_helper'

describe Agents::EmailAgent do
  it_behaves_like EmailConcern

  def get_message_part(mail, content_type)
    mail.body.parts.find { |p| p.content_type.match content_type }.body.raw_source
  end

  before do
    @checker = Agents::EmailAgent.new(name: 'something', options: { expected_receive_period_in_days: '2', subject: 'something interesting' })
    @checker.user = users(:bob)
    @checker.save!
    expect(ActionMailer::Base.deliveries).to eq([])
  end

  after do
    ActionMailer::Base.deliveries = []
  end

  describe '#receive' do
    it 'immediately sends any payloads it receives' do
      message1 = Message.new
      message1.agent = agents(:bob_notifier_agent)
      message1.payload = { message: 'hi!', data: 'Something you should know about' }
      message1.save!

      message2 = Message.new
      message2.agent = agents(:bob_status_agent)
      message2.payload = { data: 'Something else you should know about' }
      message2.save!

      Agents::EmailAgent.async_receive(@checker.id, message1.id)
      Agents::EmailAgent.async_receive(@checker.id, message2.id)

      expect(ActionMailer::Base.deliveries.count).to eq(2)
      expect(ActionMailer::Base.deliveries.last.to).to eq(['bob@example.com'])
      expect(ActionMailer::Base.deliveries.last.subject).to eq('something interesting')
      expect(get_message_part(ActionMailer::Base.deliveries.last, /plain/).strip).to eq("Message\r\n  data: Something else you should know about")
      expect(get_message_part(ActionMailer::Base.deliveries.first, /plain/).strip).to eq("hi!\r\n  data: Something you should know about")
    end

    it 'logs and re-raises any mailer errors' do
      message1 = Message.new
      message1.agent = agents(:bob_notifier_agent)
      message1.payload = { message: 'hi!', data: 'Something you should know about' }
      message1.save!

      mock(SystemMailer).send_message(anything) { raise Net::SMTPAuthenticationError, 'Wrong password' }

      expect {
        Agents::EmailAgent.async_receive(@checker.id, message1.id)
      }.to raise_error(/Wrong password/)

      expect(@checker.logs.last.message).to match(/Error sending mail .* Wrong password/)
    end

    it 'can receive complex messages and send them on' do
      stub_request(:any, /example.com/).to_return(body: '', status: 200)
      stub.any_instance_of(Agents::HttpStatusAgent).is_tomorrow?(anything) { true }
      @checker.sources << agents(:bob_status_agent)

      Agent.async_check(agents(:bob_status_agent).id)

      Agent.receive!

      plain_email_text = get_message_part(ActionMailer::Base.deliveries.last, /plain/).strip
      html_email_text = get_message_part(ActionMailer::Base.deliveries.last, /html/).strip

      expect(plain_email_text).to match(/response_received/)
      expect(html_email_text).to match(/response_received/)
    end

    it "can take body option for selecting the resulting email's body" do
      @checker.update(options: @checker.options.merge({
                                                        'subject' => '{{foo.subject}}',
                                                        'body' => '{{some_html}}'
                                                      }))

      message = Message.new
      message.agent = agents(:bob_notifier_agent)
      message.payload = { foo: { subject: 'Something you should know about' }, some_html: '<strong>rain!</strong>' }
      message.save!

      Agents::EmailAgent.async_receive(@checker.id, message.id)

      expect(ActionMailer::Base.deliveries.count).to eq(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq(['bob@example.com'])
      expect(ActionMailer::Base.deliveries.last.subject).to eq('Something you should know about')
      expect(get_message_part(ActionMailer::Base.deliveries.last, /plain/).strip).to match(%r{\A\s*<strong>rain\!<\/strong>\s*\z})
      expect(get_message_part(ActionMailer::Base.deliveries.last, /html/).strip).to match(%r{<body>\s*<strong>rain\!<\/strong>\s*<\/body>})
    end

    it 'can take content type option to set content type of email sent' do
      @checker.update(options: @checker.options.merge({ 'content_type' => 'text/plain' }))

      message2 = Message.new
      message2.agent = agents(:bob_notifier_agent)
      message2.payload = { foo: { subject: 'Something you should know about' }, some_html: '<strong>rain!</strong>' }
      message2.save!

      Agents::EmailAgent.async_receive(@checker.id, message2.id)

      expect(ActionMailer::Base.deliveries.last.content_type).to eq('text/plain; charset=UTF-8')
    end
  end
end
