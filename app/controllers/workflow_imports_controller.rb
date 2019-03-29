class WorkflowImportsController < ApplicationController
  def new
    @workflow_import = WorkflowImport.new
  end

  def create
    @workflow_import = WorkflowImport.new(workflow_import_params)
    @workflow_import.set_user(current_user)

    if @workflow_import.valid? && @workflow_import.import_confirmed? && @workflow_import.import
      redirect_to @workflow_import.workflow, notice: 'Import successful!'
    else
      render action: 'new'
    end
  end

  private

  def workflow_import_params
    params.require(:workflow_import).permit(:data, :file, :do_import, merges: {})
  end
end
