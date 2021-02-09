class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper :all

  rescue_from 'ActiveRecord::SubclassNotFound' do
    @undefined_agent_types = current_user.undefined_agent_types

    respond_to do |format|
      format.html { render template: 'application/undefined_agents' }
      format.json { render json: [] }
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[username email password password_confirmation remember_me])
    devise_parameter_sanitizer.permit(:sign_in, keys: %i[login username email password remember_me])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[username email password password_confirmation current_password])
  end

  def authenticate_admin!
    redirect_to(root_path, alert: 'Admin access required to view that page.') unless current_user&.admin?
  end

  def upgrade_warning
    return unless current_user
  end

  private

  def agent_params
    return {} unless params[:agent]
    @agent_params ||= begin
      params[:agent].permit([:memory, :name, :type, :schedule, :disabled, :keep_messages_for, :drop_pending_messages,
                             source_ids: [], receiver_ids: [], workflow_ids: [], controller_ids: [], control_target_ids: []] + agent_params_options)
    end
  end

  def agent_params_options
    if params[:agent].fetch(:options, '').is_a?(ActionController::Parameters)
      [options: {}]
    else
      [:options]
    end
  end
end
