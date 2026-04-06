class SleepLog < ApplicationRecord
  belongs_to :client

  validates :bedtime, :wake_time, presence: true
  validates :quality, inclusion: { in: 1..10 }, allow_nil: true
end
