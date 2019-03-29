class MessagesController < ApplicationController
  before_action :load_agent
  before_action :load_message, except: :index

  def index
    @messages = @agent.messages
    respond_to do |format|
      format.html { render action: :index, layout: false }
    end
  end

  def show
    respond_to do |format|
      format.html { render action: :show, layout: false }
      format.json { render json: @message }
    end
  end

  def reemit
    new_message = @message.reemit!
    respond_to do |format|
      format.json { render json: new_message }
    end
  end

  def destroy
    @message.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

  def load_agent
    @agent = current_user.agents.find(params[:agent_id])
  end

  def load_message
    @message = current_user.messages.find(params[:id])
  end
end
