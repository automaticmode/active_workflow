module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :disable_registration, only: %i[create new]

    private

    def disable_registration
      head :forbidden
    end
  end
end
