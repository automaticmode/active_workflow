# A Link connects Agents in a directed Message flow from the `source` to the `receiver`.
class Link < ApplicationRecord
  belongs_to :source, class_name: 'Agent', inverse_of: :links_as_source
  belongs_to :receiver, class_name: 'Agent', inverse_of: :links_as_receiver

  before_create :store_message_id_at_creation

  def store_message_id_at_creation
    self.message_id_at_creation = source.messages.limit(1).reorder('id desc').pluck(:id).first || 0
  end
end
