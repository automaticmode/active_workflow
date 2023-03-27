class AgentsController < ApplicationController
  include DotHelper
  include ActionView::Helpers::TextHelper
  before_action :set_workflow

  def index
    @agents = current_user.agents.includes(:receivers)

    # Trigger undefined agents handling.
    @agents.map { |agent| agent } if current_user.undefined_agent_types

    respond_to do |format|
      format.html
      format.json { render json: @agents }
    end
  end

  def table
    agents = if @workflow
               @workflow.agents.preload(:workflows).includes(:receivers)
             else
               current_user.agents.preload(:workflows).includes(:receivers)
             end

    rows = agents.map do |agent|
      {
        id: agent.id,
        unavailable: agent.unavailable?,
        name: agent.name,
        messages_count: agent.messages_count,
        schedule: agent.schedule&.humanize&.titleize || '',
        human_type: agent.human_type,
        workflows: agent.workflows.pluck(:id, :name, :tag_fg_color, :tag_bg_color).map do |row|
          {
            id: row[0],
            name: row[1],
            fg_color: row[2],
            bg_color: row[3]
          }
        end,
        last_check_at: agent.last_check_at&.to_time&.to_i,
        last_receive_at: agent.last_receive_at&.to_time&.to_i,
        last_message_at: agent.last_message_at&.to_time&.to_i,
        issues: agent.issues?,
        receivers: agent.receivers.map { |receiver| { id: receiver.id } },
        action_menu: AgentsController.render(template: 'agents/_action_menu',
                                             formats: [:html],
                                             layout: false,
                                             locals: {
                                               right: true, agent: agent,
                                               workflow_id: @workflow&.id
                                             })
      }
    end

    render json: rows
  end

  def handle_details_post
    @agent = current_user.agents.find(params[:id])
    if @agent.respond_to?(:handle_details_post)
      render json: @agent.handle_details_post(params) || {}
    else
      @agent.error "#handle_details_post called on an instance of #{@agent.class} that does not define it."
      head 500
    end
  end

  def run
    @agent = current_user.agents.find(params[:id])
    Agent.async_check(@agent.id)

    respond_to do |format|
      format.html do
        redirect_back(fallback_location: agent_path(@agent),
                      notice: "Agent run queued for '#{@agent.name}'")
      end
      format.json { head :ok }
    end
  end

  def type_details
    @agent = Agent.build_for_type(params[:type], current_user, {})
    initialize_presenter

    render json: {
      can_be_scheduled: @agent.can_be_scheduled?,
      default_schedule: @agent.default_schedule,
      can_receive_messages: @agent.can_receive_messages?,
      can_create_messages: @agent.can_create_messages?,
      can_control_other_agents: @agent.can_control_other_agents?,
      can_dry_run: @agent.can_dry_run?,
      options: @agent.default_options,
      description_html: @agent.html_description,
      form_options: render_to_string(partial: 'options', locals: { agent: @agent })
    }
  end

  def message_descriptions
    html = current_user.agents.find(params[:ids].split(',')).group_by(&:type).map do |type, agents|
      agents.map(&:html_message_description).uniq.map do |desc|
        "<p><strong>#{type}</strong><br />" + desc + '</p>'
      end
    end.flatten.join
    render json: { description_html: html }
  end

  def remove_messages
    @agent = current_user.agents.find(params[:id])
    @agent.messages.delete_all

    respond_to do |format|
      format.html do
        redirect_back(fallback_location: agent_path(@agent),
                      notice: "Messages deleted for '#{@agent.name}'")
      end
      format.json { head :ok }
    end
  end

  def destroy_memory
    @agent = current_user.agents.find(params[:id])
    @agent.update!(memory: {})

    respond_to do |format|
      format.html do
        redirect_back(fallback_location: agent_path(@agent),
                      notice: "Memory erased for '#{@agent.name}'")
      end
      format.json { head :ok }
    end
  end

  def show
    @agent = current_user.agents.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: @agent }
    end
  end

  def new
    agents = current_user.agents

    @agent = if (id = params[:id])
               agents.build_clone(agents.find(id))
             else
               agents.build
             end

    @agent.workflow_ids = [params[:workflow_id]] if params[:workflow_id] && current_user.workflows.find_by(id: params[:workflow_id])

    initialize_presenter

    respond_to do |format|
      format.html
      format.json { render json: @agent }
    end
  end

  def edit
    @agent = current_user.agents.find(params[:id])

    initialize_presenter
  end

  def create
    build_agent

    respond_to do |format|
      if @agent.save
        format.html do
          if params[:workflow_id] && current_user.workflows.find_by(id: params[:workflow_id])
            redirect_to(workflow_path(@workflow), notice: "'#{@agent.name}' was successfully created.")
          else
            redirect_to(agents_path, notice: "'#{@agent.name}' was successfully created.")
          end
        end
        format.json { render json: @agent, status: :ok, location: agent_path(@agent) }
      else
        initialize_presenter
        format.html { render action: 'new' }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @agent = current_user.agents.find(params[:id])

    respond_to do |format|
      if @agent.update(agent_params)
        format.html do
          redirect_back(fallback_location: agent_path(@agent),
                        notice: "'#{@agent.name}' was successfully updated.")
        end
        format.json { render json: @agent, status: :ok, location: agent_path(@agent) }
      else
        initialize_presenter
        format.html { render action: 'edit' }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
      end
    end
  end

  def leave_workflow
    @agent = current_user.agents.find(params[:id])
    @workflow = current_user.workflows.find(params[:workflow_id])
    @agent.workflows.destroy(@workflow)

    respond_to do |format|
      format.html do
        redirect_back(fallback_location: agent_path(@agent),
                      notice: "'#{@agent.name}' removed from '#{@workflow.name}'")
      end
      format.json { head :no_content }
    end
  end

  def destroy
    @agent = current_user.agents.find(params[:id])
    @agent.destroy

    respond_to do |format|
      format.html do
        if params[:workflow_id] && current_user.workflows.find_by(id: params[:workflow_id])
          redirect_to(workflow_path(id: params[:workflow_id]))
        else

          redirect_to(agents_path, notice: "'#{@agent.name}' deleted")
        end
      end
      format.json { head :no_content }
    end
  end

  def validate
    build_agent

    if @agent.validate_option(params[:attribute])
      render plain: 'ok'
    else
      render plain: 'error', status: 403
    end
  end

  def complete
    build_agent

    render json: @agent.complete_option(params[:attribute])
  end

  def destroy_undefined
    current_user.undefined_agents.destroy_all

    redirect_back(fallback_location: agents_path,
                  notice: 'All undefined Agents have been deleted.')
  end

  protected

  def build_agent
    @agent = Agent.build_for_type(agent_params[:type],
                                  current_user,
                                  agent_params.except(:type))
  end

  def initialize_presenter
    return unless @agent.present? && @agent.form_configurable?

    @agent = FormConfigurableAgentPresenter.new(@agent, view_context)
  end

  private

  def set_workflow
    return unless params[:workflow_id]

    @workflow = current_user.workflows.find_by(id: params[:workflow_id])
  end
end
