require 'agents_exporter'

class WorkflowsController < ApplicationController
  skip_before_action :authenticate_user!, only: :export

  def index
    @workflows = current_user.workflows
    @agents = current_user.agents.includes(:receivers)

    respond_to do |format|
      format.html
      format.json { render json: @workflows }
    end
  end

  def new
    @workflow = current_user.workflows.build

    respond_to do |format|
      format.html
      format.json { render json: @workflow }
    end
  end

  def show
    @workflow = current_user.workflows.find(params[:id])

    @agents = @workflow.agents.includes(:receivers)

    respond_to do |format|
      format.html
      format.json { render json: @workflow }
    end
  end

  def share
    @workflow = current_user.workflows.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: @workflow }
    end
  end

  def export
    @workflow = Workflow.find(params[:id])
    raise ActiveRecord::RecordNotFound unless current_user && current_user.id == @workflow.user_id

    @exporter = AgentsExporter.new(name: @workflow.name,
                                   description: @workflow.description,
                                   guid: @workflow.guid,
                                   tag_fg_color: @workflow.tag_fg_color,
                                   tag_bg_color: @workflow.tag_bg_color,
                                   icon: @workflow.icon,
                                   agents: @workflow.agents)
    response.headers['Content-Disposition'] = 'attachment; filename="' + @exporter.filename + '"'
    render json: JSON.pretty_generate(@exporter.as_json)
  end

  def edit
    @workflow = current_user.workflows.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: @workflow }
    end
  end

  def create
    @workflow = current_user.workflows.build(workflow_params)

    respond_to do |format|
      if @workflow.save
        format.html { redirect_to @workflow, notice: 'This workflow was successfully created.' }
        format.json { render json: @workflow, status: :created, location: @workflow }
      else
        format.html { render action: 'new' }
        format.json { render json: @workflow.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @workflow = current_user.workflows.find(params[:id])

    respond_to do |format|
      if @workflow.update(workflow_params)
        format.html { redirect_to @workflow, notice: 'This workflow was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @workflow.errors, status: :unprocessable_entity }
      end
    end
  end

  def enable_or_disable_all_agents
    @workflow = current_user.workflows.find(params[:id])

    @workflow.agents.update_all(disabled: params[:workflow][:disabled] == 'true')
    respond_to do |format|
      format.html { redirect_to @workflow, notice: 'The agents in this workflow have been successfully updated.' }
      format.json { head :no_content }
    end
  end

  def destroy
    @workflow = current_user.workflows.find(params[:id])
    @workflow.destroy_with_mode(params[:mode])

    respond_to do |format|
      format.html { redirect_to workflows_path }
      format.json { head :no_content }
    end
  end

  private

  def workflow_params
    params.require(:workflow).permit(:name, :description,
                                     :tag_fg_color, :tag_bg_color, :icon, agent_ids: [])
  end
end
