class EnergyLog < ApplicationRecord
  belongs_to :client

  validates :level, presence: true, inclusion: { in: 1..10 }
  validates :recorded_at, presence: true
end
