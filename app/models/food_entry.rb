class FoodEntry < ApplicationRecord
  belongs_to :client

  validates :consumed_at, presence: true
  validates :meal_type, inclusion: { in: %w[breakfast lunch dinner snack] }, allow_nil: true
end
