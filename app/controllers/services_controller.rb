class ServicesController < ApplicationController
  before_action :upgrade_warning, only: :index

  def index
    @services = current_user.services

    respond_to do |format|
      format.html
      format.json { render json: @services }
    end
  end

  def destroy
    @services = current_user.services.find(params[:id])
    @services.destroy

    respond_to do |format|
      format.html { redirect_to services_path }
      format.json { head :no_content }
    end
  end

  def toggle_availability
    @service = current_user.services.find(params[:id])
    @service.toggle_availability!

    respond_to do |format|
      format.html { redirect_to services_path }
      format.json { render json: @service }
    end
  end
end
