require 'rails_helper'

describe WorkflowsController do
  def valid_attributes(options = {})
    { name: 'some_name' }.merge(options)
  end

  before do
    sign_in users(:bob)
  end

  describe 'GET index' do
    it 'only returns Workflows for the current user' do
      get :index
      expect(assigns(:workflows).all? { |i| expect(i.user).to eq(users(:bob)) }).to be_truthy
    end
  end

  describe 'GET show' do
    it 'only shows Workflows for the current user' do
      get :show, params: { id: workflows(:bob_status).to_param }
      expect(assigns(:workflow)).to eq(workflows(:bob_status))

      expect {
        get :show, params: { id: workflows(:jane_status).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'loads Agents for the requested Workflow' do
      get :show, params: { id: workflows(:bob_status).to_param }
      expect(assigns(:agents).pluck(:id).sort).to eq(workflows(:bob_status).agents.pluck(:id).sort)
    end
  end

  describe 'GET share' do
    it 'only displays Workflow share information for the current user' do
      get :share, params: { id: workflows(:bob_status).to_param }
      expect(assigns(:workflow)).to eq(workflows(:bob_status))

      expect {
        get :share, params: { id: workflows(:jane_status).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET export' do
    it 'returns a JSON file download from an instantiated AgentsExporter' do
      get :export, params: { id: workflows(:bob_status).to_param }
      expect(assigns(:exporter).options[:name]).to eq(workflows(:bob_status).name)
      expect(assigns(:exporter).options[:description]).to eq(workflows(:bob_status).description)
      expect(assigns(:exporter).options[:agents]).to eq(workflows(:bob_status).agents)
      expect(assigns(:exporter).options[:guid]).to eq(workflows(:bob_status).guid)
      expect(assigns(:exporter).options[:tag_fg_color]).to eq(workflows(:bob_status).tag_fg_color)
      expect(assigns(:exporter).options[:tag_bg_color]).to eq(workflows(:bob_status).tag_bg_color)
      expect(response.headers['Content-Disposition']).to eq('attachment; filename="bob-s-status-alert-workflow.json"')
      expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
      expect(JSON.parse(response.body)['name']).to eq(workflows(:bob_status).name)
    end

    it 'only exports private Workflows for the current user' do
      get :export, params: { id: workflows(:bob_status).to_param }
      expect(assigns(:workflow)).to eq(workflows(:bob_status))

      expect {
        get :export, params: { id: workflows(:jane_status).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET edit' do
    it 'only shows Workflows for the current user' do
      get :edit, params: { id: workflows(:bob_status).to_param }
      expect(assigns(:workflow)).to eq(workflows(:bob_status))

      expect {
        get :edit, params: { id: workflows(:jane_status).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST create' do
    it 'creates Workflows for the current user' do
      expect {
        post :create, params: { workflow: valid_attributes }
      }.to change { users(:bob).workflows.count }.by(1)
    end

    it 'shows errors' do
      expect {
        post :create, params: { workflow: valid_attributes(name: '') }
      }.not_to change { users(:bob).workflows.count }
      expect(assigns(:workflow)).to have(1).errors_on(:name)
      expect(response).to render_template('new')
    end

    it 'will not create Workflows for other users' do
      expect {
        post :create, params: { workflow: valid_attributes(user_id: users(:jane).id) }
      }.to raise_error(ActionController::UnpermittedParameters)
    end
  end

  describe 'PUT update' do
    it 'updates attributes on Workflows for the current user' do
      post :update, params: { id: workflows(:bob_status).to_param, workflow: { name: 'new_name' } }
      expect(response).to redirect_to(workflow_path(workflows(:bob_status)))
      expect(workflows(:bob_status).reload.name).to eq('new_name')

      expect {
        post :update, params: { id: workflows(:jane_status).to_param, workflow: { name: 'new_name' } }
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(workflows(:jane_status).reload.name).not_to eq('new_name')
    end

    it 'shows errors' do
      post :update, params: { id: workflows(:bob_status).to_param, workflow: { name: '' } }
      expect(assigns(:workflow)).to have(1).errors_on(:name)
      expect(response).to render_template('edit')
    end

    it 'adds an agent to the workflow' do
      expect {
        post :update, params: { id: workflows(:bob_status).to_param, workflow: { name: 'new_name', agent_ids: workflows(:bob_status).agent_ids + [agents(:bob_website_agent).id] } }
      }.to change { workflows(:bob_status).reload.agent_ids.length }.by(1)
    end
  end

  describe 'PUT enable_or_disable_all_agents' do
    it 'updates disabled on all agents in a workflow for the current user' do
      @params = { 'workflow' => { 'disabled' => 'true' }, 'commit' => 'Yes', 'id' => workflows(:bob_status).id }
      put :enable_or_disable_all_agents, params: @params
      expect(agents(:bob_notifier_agent).disabled).to eq(true)
      expect(response).to redirect_to(workflow_path(workflows(:bob_status)))
    end
  end

  describe 'DELETE destroy' do
    it 'destroys only Workflows owned by the current user' do
      expect {
        delete :destroy, params: { id: workflows(:bob_status).to_param }
      }.to change(Workflow, :count).by(-1)

      expect {
        delete :destroy, params: { id: workflows(:jane_status).to_param }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'passes the mode to the model' do
      expect {
        delete :destroy, params: { id: workflows(:bob_status).to_param, mode: 'all_agents' }
      }.to change(Agent, :count).by(-2)
    end
  end
end
