module API
  module V1
    module Entities
      class Message < Grape::Entity
        expose :id
        expose :agent_id
        expose :created_at
        expose :expires_at
        expose :payload, if: lambda { |_, options| options[:with_payload] == true }
      end
    end
  end
end

