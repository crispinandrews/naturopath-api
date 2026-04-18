class Supplement < ApplicationRecord
  belongs_to :client

  validates :name, presence: true
  validates :taken_at, presence: true
  validates :client_uuid, uniqueness: { scope: :client_id }, allow_nil: true
end
