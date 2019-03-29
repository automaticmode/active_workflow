require 'rails_helper'

describe WorkflowImportsController do
  let(:user) { users(:bob) }

  before do
    login_as(user)
  end

  it 'renders the import form' do
    visit new_workflow_imports_path
    expect(page).to have_text('Import Workflow')
  end

  it 'requires a file upload' do
    visit new_workflow_imports_path
    click_on 'Start Import'
    expect(page).to have_text('Please provide a Workflow JSON File.')
  end

  it 'imports a workflow that does not exist yet' do
    visit new_workflow_imports_path
    attach_file('Upload a Workflow JSON File', File.join(Rails.root, 'data/default_workflow.json'))
    click_on 'Start Import'
    expect(page).to have_text('This workflow was created just for demonstration purposes.')
    expect(page).not_to have_text('This Workflow already exists in your system.')
    check('I confirm that I want to import these Agents.')
    click_on 'Finish Import'
    expect(page).to have_text('Import successful!')
  end

  it 'asks to accept conflicts when the workflow was modified' do
    DefaultWorkflowImporter.seed(user)
    agent = user.agents.where(name: 'ApplePrivacyPolicy').first
    agent.options['expected_receive_period_in_days'] = 9001
    agent.save!
    visit new_workflow_imports_path
    attach_file('Upload a Workflow JSON File', File.join(Rails.root, 'data/default_workflow.json'))
    click_on 'Start Import'
    expect(page).to have_text('This Workflow already exists in your system.')
    expect(page).to have_text('9001')
    check('I confirm that I want to import these Agents.')
    click_on 'Finish Import'
    expect(page).to have_text('Import successful!')
  end
end
