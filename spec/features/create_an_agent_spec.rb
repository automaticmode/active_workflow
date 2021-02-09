require 'rails_helper'

describe 'Creating a new agent', js: true do
  before(:each) do
    login_as(users(:bob))
  end

  it 'creates an agent' do
    visit '/'
    page.find('a', text: 'Agents').click
    click_on('New Agent', match: :first)

    select_agent_type('Trigger Agent')
    fill_in(:agent_name, with: 'Test Trigger Agent')
    click_on 'Save'

    expect(page).to have_text('Test Trigger Agent')
  end

  context 'with associated agents' do
    let!(:bob_commander_agent) {
      Agents::CommanderAgent.create!(
        user: users(:bob),
        name: 'Example Commander',
        schedule: 'never',
        options: {
          'action' => 'run'
        }
      )
    }

    let!(:bob_status_agent) {
      agents(:bob_status_agent)
    }

    let!(:bob_formatting_agent) {
      agents(:bob_formatting_agent).tap { |agent|
        # Make this valid
        agent.options['instructions']['foo'] = 'bar'
        agent.save!
      }
    }

    it 'creates an agent with a source and a receiver' do
      visit '/'
      page.find('a', text: 'Agents').click
      click_on('New Agent', match: :first)

      select_agent_type('Trigger Agent')
      fill_in(:agent_name, with: 'Test Trigger Agent')

      select2('Site status', from: 'Sources')
      select2('Formatting Agent', from: 'Receivers')

      click_on 'Save'

      expect(page).to have_text('Test Trigger Agent')

      agent = Agent.find_by(name: 'Test Trigger Agent')

      expect(agent.sources).to eq([bob_status_agent])
      expect(agent.receivers).to eq([bob_formatting_agent])
    end

    it 'creates an agent with a control target' do
      visit '/'
      page.find('a', text: 'Agents').click
      click_on('New Agent', match: :first)

      select_agent_type('Commander Agent')
      fill_in(:agent_name, with: 'Test Commander Agent')

      select2('Site status', from: 'Control targets')

      click_on 'Save'

      expect(page).to have_text('Test Commander Agent')

      agent = Agent.find_by(name: 'Test Commander Agent')

      expect(agent.control_targets).to eq([bob_status_agent])
    end
  end

  it 'creates an alert if a new agent with invalid json is submitted' do
    visit '/'
    page.find('a', text: 'Agents').click
    click_on('New Agent', match: :first)

    select_agent_type('Trigger Agent')
    fill_in(:agent_name, with: 'Test Trigger Agent')

    fill_in_editor(:agent_options, with: '{
      "expected_receive_period_in_days": "2"
      "keep_message": "false"
    }')
    expect(get_alert_text_from { click_on 'Save' }).to have_text('Sorry, there appears to be an error in your JSON input. Please fix it before continuing.')
  end

  context 'displaying the correct information' do
    before(:each) do
      visit new_agent_path
    end

    it 'shows all options for agents that can be scheduled, create and receive messages' do
      select_agent_type('Website Agent')
      expect(page).not_to have_content('This type of agent cannot create messages.')
    end

    it 'does not show the target select2 field when the agent can not create messages' do
      select_agent_type('Email Agent')
      expect(page).to have_content('This type of agent cannot create messages.')
    end
  end

  it 'allows to click on on the agent name in select2 tags' do
    visit new_agent_path
    select_agent_type('Website Agent')
    select2('Site status', from: 'Sources')
    click_on 'Site status'
    expect(page).to have_content 'Editing your HTTP Status Agent'
  end
end
