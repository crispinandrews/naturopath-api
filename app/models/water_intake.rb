class WaterIntake < ApplicationRecord
  belongs_to :client

  validates :amount_ml, presence: true, numericality: { greater_than: 0 }
  validates :recorded_at, presence: true
end
