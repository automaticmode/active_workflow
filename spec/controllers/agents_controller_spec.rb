require 'rails_helper'

describe AgentsController do
  def valid_attributes(options = {})
    {
      type: 'Agents::WebsiteAgent',
      name: 'Something',
      options: agents(:bob_website_agent).options,
      source_ids: [agents(:bob_status_agent).id, '']
    }.merge(options)
  end

  describe 'GET index' do
    it 'only returns Agents for the current user' do
      sign_in users(:bob)
      get :index
      expect(assigns(:agents).all? { |i| expect(i.user).to eq(users(:bob)) }).to be_truthy
    end
  end

  describe 'GET table' do
    it 'returns message counts for users agents' do
      sign_in users(:bob)
      get :table
      JSON.parse(response.body).each do |row|
        expect(row['messages_count']).to eq Agent.find(row['id']).messages_count
      end
    end
  end

  describe 'POST handle_details_post' do
    it 'passes control to handle_details_post on the agent' do
      sign_in users(:bob)
      post :handle_details_post, params: { id: agents(:bob_manual_message_agent).to_param, payload: { foo: 'bar' }.to_json }
      expect(JSON.parse(response.body)).to eq({ 'success' => true })
      expect(agents(:bob_manual_message_agent).messages.last.payload).to eq({ 'foo' => 'bar' })
    end

    it "can only be accessed by the Agent's owner" do
      sign_in users(:jane)
      expect {
        post :handle_details_post, params: { id: agents(:bob_manual_message_agent).to_param, payload: { foo: :bar }.to_json }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST run' do
    it "triggers Agent.async_check with the Agent's ID" do
      sign_in users(:bob)
      mock(Agent).async_check(agents(:bob_manual_message_agent).id)
      post :run, params: { id: agents(:bob_manual_message_agent).to_param }
    end

    it "can only be accessed by the Agent's owner" do
      sign_in users(:jane)
      expect {
        post :run, params: { id: agents(:bob_manual_message_agent).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST remove_messages' do
    it 'deletes all messages created by the given Agent' do
      sign_in users(:bob)
      agent_message = messages(:bob_website_agent_message).id
      other_message = messages(:jane_website_agent_message).id
      post :remove_messages, format: 'json',
        params: { id: agents(:bob_website_agent).to_param }
      expect(Message.where(id: agent_message).count).to eq(0)
      expect(Message.where(id: other_message).count).to eq(1)
    end

    it "can only be accessed by the Agent's owner" do
      sign_in users(:jane)
      expect {
        post :remove_messages, params: { id: agents(:bob_website_agent).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET show' do
    it 'only shows Agents for the current user' do
      sign_in users(:bob)
      get :show, params: { id: agents(:bob_website_agent).to_param }
      expect(assigns(:agent)).to eq(agents(:bob_website_agent))

      expect {
        get :show, params: { id: agents(:jane_website_agent).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET new' do
    describe 'with :id' do
      it 'opens a clone of a given Agent' do
        sign_in users(:bob)
        get :new, params: { id: agents(:bob_website_agent).to_param }
        expect(assigns(:agent).attributes).to eq(users(:bob).agents.build_clone(agents(:bob_website_agent)).attributes)
      end

      it 'only allows the current user to clone his own Agent' do
        sign_in users(:bob)

        expect {
          get :new, params: { id: agents(:jane_website_agent).to_param }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'with a workflow_id' do
      it 'populates the assigned agent with the workflow' do
        sign_in users(:bob)
        get :new, params: { workflow_id: workflows(:bob_status).id }
        expect(assigns(:agent).workflow_ids).to eq([workflows(:bob_status).id])
      end

      it "does not see other user's workflows" do
        sign_in users(:bob)
        get :new, params: { workflow_id: workflows(:jane_status).id }
        expect(assigns(:agent).workflow_ids).to eq([])
      end
    end
  end

  describe 'GET edit' do
    it 'only shows Agents for the current user' do
      sign_in users(:bob)
      get :edit, params: { id: agents(:bob_website_agent).to_param }
      expect(assigns(:agent)).to eq(agents(:bob_website_agent))

      expect {
        get :edit, params: { id: agents(:jane_website_agent).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST create' do
    it 'errors on bad types' do
      sign_in users(:bob)
      expect {
        post :create, params: { agent: valid_attributes(type: 'Agents::ThisIsFake') }
      }.not_to change { users(:bob).agents.count }
      expect(assigns(:agent)).to be_a(Agent)
      expect(assigns(:agent)).to have(1).error_on(:type)

      sign_in users(:bob)
      expect {
        post :create, params: { agent: valid_attributes(type: 'Object') }
      }.not_to change { users(:bob).agents.count }
      expect(assigns(:agent)).to be_a(Agent)
      expect(assigns(:agent)).to have(1).error_on(:type)
      sign_in users(:bob)

      expect {
        post :create, params: { agent: valid_attributes(type: 'Agent') }
      }.not_to change { users(:bob).agents.count }
      expect(assigns(:agent)).to be_a(Agent)
      expect(assigns(:agent)).to have(1).error_on(:type)

      expect {
        post :create, params: { agent: valid_attributes(type: 'User') }
      }.not_to change { users(:bob).agents.count }
      expect(assigns(:agent)).to be_a(Agent)
      expect(assigns(:agent)).to have(1).error_on(:type)
    end

    it 'creates Agents for the current user' do
      sign_in users(:bob)
      expect {
        expect {
          post :create, params: { agent: valid_attributes }
        }.to change { users(:bob).agents.count }.by(1)
      }.to change { Link.count }.by(1)
      expect(assigns(:agent)).to be_a(Agents::WebsiteAgent)
    end

    it 'creates Agents and accepts specifing a target agent' do
      sign_in users(:bob)
      attributes = valid_attributes(service_id: 1)
      attributes[:receiver_ids] = attributes[:source_ids]
      expect {
        expect {
          post :create, params: { agent: attributes }
        }.to change { users(:bob).agents.count }.by(1)
      }.to change { Link.count }.by(2)
      expect(assigns(:agent)).to be_a(Agents::WebsiteAgent)
    end

    it 'shows errors' do
      sign_in users(:bob)
      expect {
        post :create, params: { agent: valid_attributes(name: '') }
      }.not_to change { users(:bob).agents.count }
      expect(assigns(:agent)).to have(1).errors_on(:name)
      expect(response).to render_template('new')
    end

    it 'will not accept Agent sources owned by other users' do
      sign_in users(:bob)
      expect {
        expect {
          post :create, params: { agent: valid_attributes(source_ids: [agents(:jane_status_agent).id]) }
        }.not_to change { users(:bob).agents.count }
      }.not_to change { Link.count }
    end
  end

  describe 'PUT update' do
    it 'does not allow changing types' do
      sign_in users(:bob)
      post :update, params: { id: agents(:bob_website_agent).to_param, agent: valid_attributes(type: 'Agents::HttpStatusAgent') }
      expect(assigns(:agent)).to have(1).errors_on(:type)
      expect(response).to render_template('edit')
    end

    it 'updates attributes on Agents for the current user' do
      sign_in users(:bob)
      post :update, params: { id: agents(:bob_website_agent).to_param, agent: valid_attributes(name: 'New name') }
      expect(response).to redirect_to(agent_path(agents(:bob_website_agent)))
      expect(agents(:bob_website_agent).reload.name).to eq('New name')

      expect {
        post :update, params: { id: agents(:jane_website_agent).to_param, agent: valid_attributes(name: 'New name') }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'accepts JSON requests' do
      sign_in users(:bob)
      post :update, params: { id: agents(:bob_website_agent).to_param, agent: valid_attributes(name: 'New name') }, format: :json
      expect(agents(:bob_website_agent).reload.name).to eq('New name')
      expect(JSON.parse(response.body)['name']).to eq('New name')
      expect(response).to be_successful
    end

    it 'will not accept Agent sources owned by other users' do
      sign_in users(:bob)
      post :update, params: { id: agents(:bob_website_agent).to_param, agent: valid_attributes(source_ids: [agents(:jane_status_agent).id]) }
      expect(assigns(:agent)).to have(1).errors_on(:sources)
    end

    it 'will not accept Workflow owned by other users' do
      sign_in users(:bob)
      post :update, params: { id: agents(:bob_website_agent).to_param, agent: valid_attributes(workflow_ids: [workflows(:jane_status).id]) }
      expect(assigns(:agent)).to have(1).errors_on(:workflows)
    end

    it 'shows errors' do
      sign_in users(:bob)
      post :update, params: { id: agents(:bob_website_agent).to_param, agent: valid_attributes(name: '') }
      expect(assigns(:agent)).to have(1).errors_on(:name)
      expect(response).to render_template('edit')
    end

    it 'does not allow to modify the agents user_id' do
      sign_in users(:bob)
      expect {
        post :update, params: { id: agents(:bob_website_agent).to_param, agent: valid_attributes(user_id: users(:jane).id) }
      }.to raise_error(ActionController::UnpermittedParameters)
    end

    describe 'redirecting back' do
      before do
        sign_in users(:bob)
      end

      it 'can redirect back to the show path' do
        post :update, params: { id: agents(:bob_website_agent).to_param, agent: valid_attributes(name: 'New name') }
        expect(response).to redirect_to(agent_path(agents(:bob_website_agent)))
      end

      it 'redirect back to the agent show path by default' do
        post :update, params: { id: agents(:bob_website_agent).to_param, agent: valid_attributes(name: 'New name') }
        expect(response).to redirect_to(agent_path(agents(:bob_website_agent)))
      end
    end

    it 'updates last_checked_message_id when drop_pending_messages is given' do
      sign_in users(:bob)
      agent = agents(:bob_website_agent)
      agent.disabled = true
      agent.last_checked_message_id = nil
      agent.save!
      post :update, params: { id: agents(:bob_website_agent).to_param, agent: { disabled: 'false', drop_pending_messages: 'true' } }
      agent.reload
      expect(agent.disabled).to eq(false)
      expect(agent.last_checked_message_id).to eq(Message.maximum(:id))
    end
  end

  describe 'PUT leave_workflow' do
    it 'removes an Agent from the given Workflow for the current user' do
      sign_in users(:bob)

      expect(agents(:bob_status_agent).workflows).to include(workflows(:bob_status))
      put :leave_workflow, params: { id: agents(:bob_status_agent).to_param, workflow_id: workflows(:bob_status).to_param }
      expect(agents(:bob_status_agent).workflows).not_to include(workflows(:bob_status))

      expect(Workflow.where(id: workflows(:bob_status).id)).to exist

      expect {
        put :leave_workflow, params: { id: agents(:jane_status_agent).to_param, workflow_id: workflows(:jane_status).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE destroy' do
    it 'destroys only Agents owned by the current user' do
      sign_in users(:bob)
      expect {
        delete :destroy, params: { id: agents(:bob_website_agent).to_param }
      }.to change(Agent, :count).by(-1)

      expect {
        delete :destroy, params: { id: agents(:jane_website_agent).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'redirects correctly when the Agent is deleted from the Agent itself' do
      sign_in users(:bob)

      delete :destroy, params: { id: agents(:bob_website_agent).to_param }
      expect(response).to redirect_to agents_path
    end

    it 'redirects correctly when the Agent is deleted from a Workflow' do
      sign_in users(:bob)

      delete :destroy, params: { id: agents(:bob_status_agent).to_param }
      expect(response).to redirect_to agents_path()
    end
  end

  describe '#form_configurable actions' do
    before(:each) do
      @params = { attribute: 'url',
                  agent: valid_attributes(type: 'Agents::HttpStatusAgent',
                                          options: {
                                            url: 'https://example.com'
                                          }) }
      sign_in users(:bob)
    end

    describe 'POST validate' do
      it 'returns with status 200 when called with a valid option' do
        any_instance_of(Agents::HttpStatusAgent) do |klass|
          stub(klass).validate_option { true }
        end

        post :validate, params: @params
        expect(response.status).to eq 200
      end

      it 'returns with status 403 when called with an invalid option' do
        any_instance_of(Agents::HttpStatusAgent) do |klass|
          stub(klass).validate_option { false }
        end

        post :validate, params: @params
        expect(response.status).to eq 403
      end
    end

    describe 'POST complete' do
      it 'callsAgent#complete_option and renders json' do
        any_instance_of(Agents::HttpStatusAgent) do |klass|
          stub(klass).complete_option { [{ name: 'test', value: 1 }] }
        end

        post :complete, params: @params
        expect(response.status).to eq 200
        expect(response.header['Content-Type']).to include('application/json')
      end
    end
  end

  describe 'DELETE memory' do
    it 'clears memory of the agent' do
      agent = agents(:bob_website_agent)
      agent.update!(memory: { 'test' => 42 })
      sign_in users(:bob)
      delete :destroy_memory, params: { id: agent.to_param }
      expect(agent.reload.memory).to eq({})
    end

    it 'does not clear memory of an agent not owned by the current user' do
      agent = agents(:jane_website_agent)
      agent.update!(memory: { 'test' => 42 })
      sign_in users(:bob)
      expect {
        delete :destroy_memory, params: { id: agent.to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(agent.reload.memory).to eq({ 'test' => 42 })
    end
  end

  describe 'DELETE undefined' do
    it 'removes an undefined agent from the database' do
      sign_in users(:bob)
      agent = agents(:bob_website_agent)
      agent.update_attribute(:type, 'Agents::UndefinedAgent')
      agent2 = agents(:jane_website_agent)
      agent2.update_attribute(:type, 'Agents::UndefinedAgent')

      expect {
        delete :destroy_undefined
      }.to change { Agent.count }.by(-1)
    end
  end
end
