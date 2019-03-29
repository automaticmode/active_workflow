require 'rails_helper'

module Users
  describe RegistrationsController do
    before do
      @request.env['devise.mapping'] = Devise.mappings[:user]
    end

    describe 'GET new' do
      it 'forbids new registrations' do
        get :new

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe 'POST create' do
      it 'forbids new registrations' do
        post :create, params: {
          user: { username: 'jdoe', email: 'jdoe@example.com',
                  password: 's3cr3t55', password_confirmation: 's3cr3t55' }
        }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
