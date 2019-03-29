class WorkflowMembership < ApplicationRecord
  belongs_to :agent, inverse_of: :workflow_memberships
  belongs_to :workflow, inverse_of: :workflow_memberships
end
