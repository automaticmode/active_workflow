require 'rails_helper'

describe WorkflowImportsController do
  let(:user) { users(:bob) }
  let(:workflow_file) { File.join(Rails.root, 'spec', 'fixtures', 'test_default_workflow.json') }

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
    expect(page).to have_text('Please provide a workflow JSON File.')
  end

  it 'imports a workflow that does not exist yet' do
    visit new_workflow_imports_path
    attach_file('Upload a workflow JSON File', workflow_file)
    click_on 'Start Import'
    expect(page).to have_text('This workflow has a few agents to get you started.')
    expect(page).not_to have_text('This workflow already exists in your system.')
    check('I confirm that I want to import these agents.')
    click_on 'Finish Import'
    expect(page).to have_text('Import successful!')
  end

  it 'asks to accept conflicts when the workflow was modified' do
    stub.proxy(ENV).[](anything)
    stub(ENV).[]('DEFAULT_WORKFLOW_FILE') { workflow_file }
    DefaultWorkflowImporter.seed(user)
    agent = user.agents.where(name: 'Rain Notifier').first
    agent.options['expected_receive_period_in_days'] = 9001
    agent.save!
    visit new_workflow_imports_path
    attach_file('Upload a workflow JSON File', workflow_file)
    click_on 'Start Import'
    expect(page).to have_text('This workflow already exists in your system.')
    expect(page).to have_text('9001')
    check('I confirm that I want to import these agents.')
    click_on 'Finish Import'
    expect(page).to have_text('Import successful!')
  end
end
