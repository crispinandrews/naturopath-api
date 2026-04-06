class Supplement < ApplicationRecord
  belongs_to :client

  validates :name, presence: true
  validates :taken_at, presence: true
end
