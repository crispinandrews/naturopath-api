class EnergyLog < ApplicationRecord
  belongs_to :client

  validates :level, presence: true, inclusion: { in: 1..10 }
  validates :recorded_at, presence: true
  validates :client_uuid, uniqueness: { scope: :client_id }, allow_nil: true
end
