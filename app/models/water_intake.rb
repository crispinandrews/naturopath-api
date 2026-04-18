class WaterIntake < ApplicationRecord
  belongs_to :client

  validates :amount_ml, presence: true, numericality: { greater_than: 0 }
  validates :recorded_at, presence: true
  validates :client_uuid, uniqueness: { scope: :client_id }, allow_nil: true
end
