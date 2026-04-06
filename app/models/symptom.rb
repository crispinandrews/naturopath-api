class Symptom < ApplicationRecord
  belongs_to :client

  validates :name, presence: true
  validates :occurred_at, presence: true
  validates :severity, inclusion: { in: 1..10 }, allow_nil: true
end
