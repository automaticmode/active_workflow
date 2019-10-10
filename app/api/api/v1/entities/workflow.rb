module API
  module V1
    module Entities
      class Workflow < Grape::Entity
        expose :id
        expose :name
        expose :description
        expose :agents, using: API::V1::Entities::Agent, if: lambda { |_, opt| opt[:with_agents] }
      end
    end
  end
end

