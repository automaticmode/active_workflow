require 'rails_helper'

describe 'Dry running an Agent', js: true do
  let(:agent) { agents(:bob_website_agent) }
  let(:formatting_agent) { agents(:bob_formatting_agent) }
  let(:user)    { users(:bob) }
  let(:emitter) { agents(:bob_status_agent) }

  before(:each) do
    login_as(user)
  end

  def open_dry_run_modal(agent)
    visit edit_agent_path(agent)
    click_on('Dry Run')
    expect(page).to have_text('Message to send')
  end

  context 'successful dry runs' do
    before do
      stub_request(:get, 'http://xkcd.com/')
        .with(headers: { 'Accept-Encoding' => 'gzip,deflate', 'User-Agent' => 'ActiveWorkflow - https://github.com/automaticmode/active_workflow' })
        .to_return(status: 200, body: File.read(Rails.root.join('spec/data_fixtures/xkcd.html')), headers: {})
    end

    it 'opens the dry run modal even when clicking on the refresh icon' do
      visit edit_agent_path(agent)
      find('.agent-dry-run-button .fa').click
      expect(page).to have_text('Message to send (Optional)')
    end

    it 'shows the dry run pop up without previous messages and selects the messages tab when a message was created' do
      open_dry_run_modal(agent)
      click_on('Dry Run')
      expect(page).to have_text('Biologists play reverse')
      expect(page).to have_selector(:css, 'li[role="presentation"].active a[href="#tabMessages"]')
    end

    it 'shows the dry run pop up with previous messages and allows use previously received message' do
      emitter.messages << Message.new(payload: { url: 'http://xkcd.com/' })
      agent.sources << emitter
      agent.options.merge!('url' => '', 'url_from_message' => '{{url}}')
      agent.save!

      open_dry_run_modal(agent)

      find('a.dry-run-message-sample').click

      expect(editor_value('payload_editor')).to include('http://xkcd.com/')
      click_on('Dry Run')
      expect(page).to have_text('Biologists play reverse')
      expect(page).to have_selector(:css, 'li[role="presentation"].active a[href="#tabMessages"]')
    end

    it 'sends escape characters correctly to the backend' do
      emitter.messages << Message.new(payload: { data: "Line 1\nLine 2\nLine 3" })
      formatting_agent.sources << emitter
      formatting_agent.options.merge!('instructions' => { 'data' => "{{data | newline_to_br | strip_newlines | split: '<br />' | join: ','}}" })
      formatting_agent.save!

      open_dry_run_modal(formatting_agent)

      find('a.dry-run-message-sample').click

      expect(editor_value('payload_editor')).to include('Line 1\nLine 2\nLine 3')

      sleep(1)
      click_on('Dry Run')
      sleep(1)

      expect(page).to have_text('Dry Run Results')
      expect(page).to have_text('Line 1,Line 2,Line 3')
      expect(page).to have_selector(:css, 'li[role="presentation"].active a[href="#tabMessages"]')
    end
  end

  it 'shows the dry run pop up without previous messages and selects the log tab when no message was created' do
    stub_request(:get, 'http://xkcd.com/')
      .with(headers: { 'Accept-Encoding' => 'gzip,deflate', 'User-Agent' => 'ActiveWorkflow - https://github.com/automaticmode/active_workflow' })
      .to_return(status: 200, body: '', headers: {})

    open_dry_run_modal(agent)
    click_on('Dry Run')
    expect(page).to have_text('Dry Run started')
    expect(page).to have_selector(:css, 'li[role="presentation"].active a[href="#tabLog"]')
  end
end
