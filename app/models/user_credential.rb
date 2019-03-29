class UserCredential < ApplicationRecord
  belongs_to :user

  validates :credential_name, presence: true
  validates :credential_value, presence: true
  validates :user_id, presence: true
  validates :credential_name, uniqueness: { scope: :user_id }

  before_save :trim_fields

  protected

  def trim_fields
    credential_name.strip!
    credential_value.strip!
  end
end
