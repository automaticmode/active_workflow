require 'rails_helper'

describe WorkflowImport do
  let(:user) { users(:bob) }
  let(:guid) { 'someworkflowguid' }
  let(:tag_fg_color) { '#ffffff' }
  let(:tag_bg_color) { '#000000' }
  let(:icon) { 'Star' }
  let(:description) { 'This is a cool ActiveWorkflow Workflow that does something useful!' }
  let(:name) { 'A useful Workflow' }
  let(:status_agent_options) {
    {
      'url' => 'http://example.com',
      'changes_only' => ''
    }
  }
  let(:trigger_agent_options) {
    {
      'expected_receive_period_in_days' => 2,
      'rules' => [{
        'type' => 'field==value',
        'value' => '200',
        'path' => 'status'
      }],
      'message' => 'Site is up.'
    }
  }
  let(:valid_parsed_status_agent_data) do
    {
      type: 'Agents::HttpStatusAgent',
      name: 'a status agent',
      schedule: '17h',
      keep_messages_for: 14.days,
      disabled: true,
      guid: 'a-status-agent',
      options: status_agent_options
    }
  end
  let(:valid_parsed_trigger_agent_data) do
    {
      type: 'Agents::TriggerAgent',
      name: 'listen for status',
      keep_messages_for: 0,
      disabled: false,
      guid: 'a-trigger-agent',
      options: trigger_agent_options
    }
  end
  let(:valid_parsed_basecamp_agent_data) do
    {
      type: 'Agents::BasecampAgent',
      name: 'Basecamp test',
      schedule: 'every_2m',
      keep_messages_for: 0,
      disabled: false,
      guid: 'a-basecamp-agent',
      options: { project_id: 12_345 }
    }
  end
  let(:valid_parsed_data) do
    {
      schema_version: 1,
      name: name,
      description: description,
      guid: guid,
      tag_fg_color: tag_fg_color,
      tag_bg_color: tag_bg_color,
      icon: icon,
      exported_at: 2.days.ago.utc.iso8601,
      agents: [
        valid_parsed_status_agent_data,
        valid_parsed_trigger_agent_data
      ],
      links: [
        { source: 0, receiver: 1 }
      ],
      control_links: []
    }
  end
  let(:valid_data) { valid_parsed_data.to_json }
  let(:invalid_data) { { name: 'some workflow missing a guid' }.to_json }

  describe 'initialization' do
    it 'is initialized with an attributes hash' do
      expect(WorkflowImport.new(data: '{}').data).to eq('{}')
    end
  end

  describe 'validations' do
    subject do
      _import = WorkflowImport.new
      _import.set_user(user)
      _import
    end

    it 'is not valid when none of file or data are present' do
      expect(subject).not_to be_valid
      expect(subject).to have(1).error_on(:base)
      expect(subject.errors[:base]).to include('Please provide a Workflow JSON File.')
    end

    describe 'data' do
      it 'should be invalid with invalid data' do
        subject.data = invalid_data
        expect(subject).not_to be_valid
        expect(subject).to have(1).error_on(:base)

        subject.data = 'foo'
        expect(subject).not_to be_valid
        expect(subject).to have(1).error_on(:base)

        # It also clears the data when invalid
        expect(subject.data).to be_nil
      end

      it 'should be valid with valid data' do
        subject.data = valid_data
        expect(subject).to be_valid
      end
    end

    describe 'file' do
      it "should be invalid when the uploaded file doesn't contain a workflow" do
        subject.file = StringIO.new('foo')
        expect(subject).not_to be_valid
        expect(subject.errors[:base]).to include('The provided data does not appear to be a valid Workflow.')

        subject.file = StringIO.new(invalid_data)
        expect(subject).not_to be_valid
        expect(subject.errors[:base]).to include('The provided data does not appear to be a valid Workflow.')
      end

      it 'should be valid with a valid uploaded workflow' do
        subject.file = StringIO.new(valid_data)
        expect(subject).to be_valid
      end
    end
  end

  describe '#import and #generate_diff' do
    let(:workflow_import) do
      _import = WorkflowImport.new(data: valid_data)
      _import.set_user users(:bob)
      _import
    end

    context 'when this workflow has never been seen before' do
      describe '#import' do
        it 'makes a new workflow' do
          expect {
            workflow_import.import(skip_agents: true)
          }.to change { users(:bob).workflows.count }.by(1)

          expect(workflow_import.workflow.name).to eq(name)
          expect(workflow_import.workflow.description).to eq(description)
          expect(workflow_import.workflow.guid).to eq(guid)
          expect(workflow_import.workflow.tag_fg_color).to eq(tag_fg_color)
          expect(workflow_import.workflow.tag_bg_color).to eq(tag_bg_color)
          expect(workflow_import.workflow.icon).to eq(icon)
        end

        it 'creates the Agents' do
          expect {
            workflow_import.import
          }.to change { users(:bob).agents.count }.by(2)

          status_agent = workflow_import.workflow.agents.find_by(guid: 'a-status-agent')
          trigger_agent = workflow_import.workflow.agents.find_by(guid: 'a-trigger-agent')

          expect(status_agent.name).to eq('a status agent')
          expect(status_agent.schedule).to eq('17h')
          expect(status_agent.keep_messages_for).to eq(14.days)
          expect(status_agent).to be_disabled
          expect(status_agent.memory).to be_empty
          expect(status_agent.options).to eq(status_agent_options)

          expect(trigger_agent.name).to eq('listen for status')
          expect(trigger_agent.sources).to eq([status_agent])
          expect(trigger_agent.schedule).to be_nil
          expect(trigger_agent.keep_messages_for).to eq(0)
          expect(trigger_agent).not_to be_disabled
          expect(trigger_agent.memory).to be_empty
          expect(trigger_agent.options).to eq(trigger_agent_options)
        end

        it "creates new Agents, even if one already exists with the given guid (so that we don't overwrite a user's work outside of the workflow)" do
          agents(:bob_status_agent).update_attribute :guid, 'a-status-agent'

          expect {
            workflow_import.import
          }.to change { users(:bob).agents.count }.by(2)
        end

        describe 'with control links' do
          it 'creates the links' do
            valid_parsed_data[:control_links] = [
              { controller: 1, control_target: 0 }
            ]

            expect {
              workflow_import.import
            }.to change { users(:bob).agents.count }.by(2)

            status_agent = workflow_import.workflow.agents.find_by(guid: 'a-status-agent')
            trigger_agent = workflow_import.workflow.agents.find_by(guid: 'a-trigger-agent')

            expect(trigger_agent.sources).to eq([status_agent])
            expect(status_agent.controllers.to_a).to eq([trigger_agent])
            expect(trigger_agent.control_targets.to_a).to eq([status_agent])
          end

          it "doesn't crash without any control links" do
            valid_parsed_data.delete(:control_links)

            expect {
              workflow_import.import
            }.to change { users(:bob).agents.count }.by(2)

            status_agent = workflow_import.workflow.agents.find_by(guid: 'a-status-agent')
            trigger_agent = workflow_import.workflow.agents.find_by(guid: 'a-trigger-agent')

            expect(trigger_agent.sources).to eq([status_agent])
          end
        end
      end

      describe '#generate_diff' do
        it 'returns AgentDiff objects for the incoming Agents' do
          expect(workflow_import).to be_valid

          agent_diffs = workflow_import.agent_diffs

          status_agent_diff = agent_diffs[0]
          trigger_agent_diff = agent_diffs[1]

          valid_parsed_status_agent_data.each do |key, value|
            if key == :type
              value = value.split('::').last
            end
            expect(status_agent_diff).to respond_to(key)
            field = status_agent_diff.send(key)
            expect(field).to be_a(WorkflowImport::AgentDiff::FieldDiff)
            expect(field.incoming).to eq(value)
            expect(field.updated).to eq(value)
            expect(field.current).to be_nil
          end

          valid_parsed_trigger_agent_data.each do |key, value|
            if key == :type
              value = value.split('::').last
            end
            expect(trigger_agent_diff).to respond_to(key)
            field = trigger_agent_diff.send(key)
            expect(field).to be_a(WorkflowImport::AgentDiff::FieldDiff)
            expect(field.incoming).to eq(value)
            expect(field.updated).to eq(value)
            expect(field.current).to be_nil
          end
          expect(trigger_agent_diff).not_to respond_to(:schedule)
        end
      end
    end

    context 'when an a workflow already exists with the given guid for the importing user' do
      let!(:existing_workflow) do
        _existing_scenerio = users(:bob).workflows.build(name: 'an existing workflow', description: 'something')
        _existing_scenerio.guid = guid
        _existing_scenerio.save!

        agents(:bob_status_agent).update_attribute :guid, 'a-status-agent'
        agents(:bob_status_agent).workflows << _existing_scenerio

        _existing_scenerio
      end

      describe '#import' do
        it 'uses the existing workflow, updating its data' do
          expect {
            workflow_import.import(skip_agents: true)
            expect(workflow_import.workflow).to eq(existing_workflow)
          }.not_to change { users(:bob).workflows.count }

          existing_workflow.reload
          expect(existing_workflow.guid).to eq(guid)
          expect(existing_workflow.tag_fg_color).to eq(tag_fg_color)
          expect(existing_workflow.tag_bg_color).to eq(tag_bg_color)
          expect(existing_workflow.icon).to eq(icon)
          expect(existing_workflow.description).to eq(description)
          expect(existing_workflow.name).to eq(name)
        end

        it 'updates any existing agents in the workflow, and makes new ones as needed' do
          expect(workflow_import).to be_valid

          expect {
            workflow_import.import
          }.to change { users(:bob).agents.count }.by(1) # One, because the status agent already existed.

          status_agent = existing_workflow.agents.find_by(guid: 'a-status-agent')
          trigger_agent = existing_workflow.agents.find_by(guid: 'a-trigger-agent')

          expect(status_agent).to eq(agents(:bob_status_agent))

          expect(status_agent.name).to eq('a status agent')
          expect(status_agent.schedule).to eq('17h')
          expect(status_agent.keep_messages_for).to eq(14.days)
          expect(status_agent).to be_disabled
          expect(status_agent.memory).to be_empty
          expect(status_agent.options).to eq(status_agent_options)

          expect(trigger_agent.name).to eq('listen for status')
          expect(trigger_agent.sources).to eq([status_agent])
          expect(trigger_agent.schedule).to be_nil
          expect(trigger_agent.keep_messages_for).to eq(0)
          expect(trigger_agent).not_to be_disabled
          expect(trigger_agent.memory).to be_empty
          expect(trigger_agent.options).to eq(trigger_agent_options)
        end

        it 'honors updates coming from the UI' do
          workflow_import.merges = {
            '0' => {
              'name' => 'updated name',
              'schedule' => '18h',
              'keep_messages_for' => 2.days.to_i.to_s,
              'disabled' => 'false',
              'options' => status_agent_options.merge('changes_only' => 'true').to_json
            }
          }

          expect(workflow_import).to be_valid

          expect(workflow_import.import).to be_truthy

          status_agent = existing_workflow.agents.find_by(guid: 'a-status-agent')
          expect(status_agent.name).to eq('updated name')
          expect(status_agent.schedule).to eq('18h')
          expect(status_agent.keep_messages_for).to eq(2.days.to_i)
          expect(status_agent).not_to be_disabled
          expect(status_agent.options).to eq(status_agent_options.merge('changes_only' => 'true'))
        end

        it 'adds errors when updated agents are invalid' do
          workflow_import.merges = {
            '0' => {
              'name' => '',
              'schedule' => 'foo',
              'keep_messages_for' => 2.days.to_i.to_s,
              'options' => status_agent_options.to_json
            }
          }

          expect(workflow_import.import).to be_falsey

          errors = workflow_import.errors.full_messages.to_sentence
          expect(errors).to match(/Name can't be blank/)
          expect(errors).to match(/Schedule is not a valid schedule/)
        end
      end

      describe '#generate_diff' do
        it "returns AgentDiff objects that include 'current' values from any agents that already exist" do
          agent_diffs = workflow_import.agent_diffs
          status_agent_diff = agent_diffs[0]
          trigger_agent_diff = agent_diffs[1]

          # Already exists
          expect(status_agent_diff.agent).to eq(agents(:bob_status_agent))
          valid_parsed_status_agent_data.each do |key, value|
            next if key == :type
            expect(status_agent_diff.send(key).current).to eq(agents(:bob_status_agent).send(key))
          end

          # Doesn't exist yet
          valid_parsed_trigger_agent_data.each do |key, value|
            expect(trigger_agent_diff.send(key).current).to be_nil
          end
        end

        it "sets the 'updated' FieldDiff values based on any feedback from the user" do
          workflow_import.merges = {
            '0' => {
              'name' => 'a new name',
              'schedule' => '18h',
              'keep_messages_for' => 2.days.to_s,
              'disabled' => 'true',
              'options' => status_agent_options.merge('changes_only' => true).to_json
            },
            '1' => {
              'name' => 'another new name'
            }
          }

          expect(workflow_import).to be_valid

          agent_diffs = workflow_import.agent_diffs
          status_agent_diff = agent_diffs[0]
          trigger_agent_diff = agent_diffs[1]

          expect(status_agent_diff.name.current).to eq(agents(:bob_status_agent).name)
          expect(status_agent_diff.name.incoming).to eq(valid_parsed_status_agent_data[:name])
          expect(status_agent_diff.name.updated).to eq('a new name')

          expect(status_agent_diff.schedule.updated).to eq('18h')
          expect(status_agent_diff.keep_messages_for.current).to eq(45.days)
          expect(status_agent_diff.keep_messages_for.updated).to eq(2.days.to_s)
          expect(status_agent_diff.disabled.updated).to eq('true')
          expect(status_agent_diff.options.updated).to eq(status_agent_options.merge('changes_only' => true))
        end

        it 'adds errors on validation when updated options are unparsable' do
          workflow_import.merges = {
            '0' => {
              'options' => '{'
            }
          }
          expect(workflow_import).not_to be_valid
          expect(workflow_import).to have(1).error_on(:base)
        end
      end
    end

    context "when Bob imports Jane's workflow" do
      let!(:existing_workflow) do
        _existing_scenerio = users(:jane).workflows.build(name: 'an existing workflow', description: 'something')
        _existing_scenerio.guid = guid
        _existing_scenerio.save!
        _existing_scenerio
      end

      describe '#import' do
        it 'makes a new workflow for Bob' do
          expect {
            workflow_import.import(skip_agents: true)
          }.to change { users(:bob).workflows.count }.by(1)

          expect(Workflow.where(guid: guid).count).to eq(2)

          expect(workflow_import.workflow.name).to eq(name)
          expect(workflow_import.workflow.description).to eq(description)
          expect(workflow_import.workflow.guid).to eq(guid)
          expect(workflow_import.workflow.tag_fg_color).to eq(tag_fg_color)
          expect(workflow_import.workflow.tag_bg_color).to eq(tag_bg_color)
          expect(workflow_import.workflow.icon).to eq(icon)
        end

        it "does not change Jane's workflow" do
          expect {
            workflow_import.import(skip_agents: true)
          }.not_to change { users(:jane).workflows }
          expect(users(:jane).workflows.find_by(guid: guid)).to eq(existing_workflow)
        end
      end
    end

    context 'agents which require a service' do
      let(:valid_parsed_services) do
        data = valid_parsed_data
        data[:agents] = [valid_parsed_basecamp_agent_data,
                         valid_parsed_trigger_agent_data]
        data
      end

      let(:valid_parsed_services_data) { valid_parsed_services.to_json }

      let(:services_workflow_import) {
        _import = WorkflowImport.new(data: valid_parsed_services_data)
        _import.set_user users(:bob)
        _import
      }

      describe '#generate_diff' do
        it 'should check if the agent requires a service' do
          agent_diffs = services_workflow_import.agent_diffs
          basecamp_agent_diff = agent_diffs[0]
          expect(basecamp_agent_diff.requires_service?).to eq(true)
        end

        it 'should add an error when no service is selected' do
          expect(services_workflow_import.import).to eq(false)
          expect(services_workflow_import.errors[:base].length).to eq(1)
        end
      end

      describe '#import' do
        it 'should import' do
          services_workflow_import.merges = {
            '0' => {
              'service_id' => '0'
            }
          }
          expect {
            expect(services_workflow_import.import).to eq(true)
          }.to change { users(:bob).agents.count }.by(2)
        end
      end
    end
  end
end
