require 'open-uri'
class DefaultWorkflowImporter
  def self.import(user)
    return unless ENV['IMPORT_DEFAULT_WORKFLOW_FOR_ALL_USERS'] == 'true'
    seed(user)
  end

  def self.seed(user)
    workflow_import = WorkflowImport.new()
    workflow_import.set_user(user)
    workflow_file = ENV['DEFAULT_WORKFLOW_FILE'].presence
    return unless workflow_file
    begin
      workflow_import.file = open(workflow_file)
      raise 'Import failed' unless workflow_import.valid? && workflow_import.import
    ensure
      workflow_import.file.close
    end
    return true
  end
end
