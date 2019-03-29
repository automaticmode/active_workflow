require 'rails_helper'

describe WorkflowImportsController do
  before do
    sign_in users(:bob)
  end

  describe 'GET new' do
    it 'initializes a new WorkflowImport and renders new' do
      get :new
      expect(assigns(:workflow_import)).to be_a(WorkflowImport)
      expect(response).to render_template(:new)
    end
  end

  describe 'POST create' do
    it 'initializes a WorkflowImport for current_user, passing in params' do
      post :create, params: { workflow_import: { data: '{}' } }
      expect(assigns(:workflow_import).user).to eq(users(:bob))
      expect(assigns(:workflow_import)).not_to be_valid
      expect(response).to render_template(:new)
    end
  end
end
