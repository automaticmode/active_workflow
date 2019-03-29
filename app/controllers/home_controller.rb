class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :upgrade_warning, only: :index

  def index
    if user_signed_in?
      redirect_to workflows_path
    else
      redirect_to new_user_session_path
    end
  end

  def about; end
end
