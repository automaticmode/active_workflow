require 'rails_helper'

describe DefaultWorkflowImporter do
  let(:user) { users(:bob) }
  describe '.import' do
    it 'imports a set of agents to get the user going when they are first created' do
      mock(DefaultWorkflowImporter).seed(is_a(User))
      stub.proxy(ENV).[](anything)
      stub(ENV).[]('IMPORT_DEFAULT_WORKFLOW_FOR_ALL_USERS') { 'true' }
      DefaultWorkflowImporter.import(user)
    end

    it 'can be turned off' do
      stub(DefaultWorkflowImporter).seed { fail 'seed should not have been called' }
      stub.proxy(ENV).[](anything)
      stub(ENV).[]('IMPORT_DEFAULT_WORKFLOW_FOR_ALL_USERS') { 'false' }
      DefaultWorkflowImporter.import(user)
    end

    it 'is turned off for existing instances of ActiveWorkflow' do
      stub(DefaultWorkflowImporter).seed { fail 'seed should not have been called' }
      stub.proxy(ENV).[](anything)
      stub(ENV).[]('IMPORT_DEFAULT_WORKFLOW_FOR_ALL_USERS') { nil }
      DefaultWorkflowImporter.import(user)
    end
  end

  describe '.seed' do
    it 'respects an environment variable that specifies a path or URL to a different workflow' do
      stub.proxy(ENV).[](anything)
      stub(ENV).[]('DEFAULT_WORKFLOW_FILE') { File.join(Rails.root, 'spec', 'fixtures', 'test_default_workflow.json') }
      expect { DefaultWorkflowImporter.seed(user) }.to change(user.agents, :count).by(3)
    end

    it 'can not be turned off' do
      stub.proxy(ENV).[](anything)
      stub(ENV).[]('DEFAULT_WORKFLOW_FILE') { File.join(Rails.root, 'spec', 'fixtures', 'test_default_workflow.json') }
      stub(ENV).[]('IMPORT_DEFAULT_WORKFLOW_FOR_ALL_USERS') { 'true' }
      expect { DefaultWorkflowImporter.seed(user) }.to change(user.agents, :count).by(3)
    end
  end
end
