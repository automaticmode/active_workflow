require 'rails_helper'

describe HomeController do
  describe 'GET index' do
    it 'redirects signed in users to workflows' do
      sign_in users(:bob)
      get :index
      expect(response).to redirect_to workflows_path
    end

    it 'redirects unsigned users to the login page' do
      get :index
      expect(response).to redirect_to new_user_session_path
    end
  end
end
