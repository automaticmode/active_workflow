module API
  module V1
    module Entities
      class Agent < Grape::Entity
        class ID < Grape::Entity
          expose :id
        end

        expose :id
        expose :name
        expose :type
        expose :messages_count
        expose :disabled
        expose :sources, using: API::V1::Entities::Agent::ID
      end
    end
  end
end

