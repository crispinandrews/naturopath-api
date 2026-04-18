RSpec.shared_context "with test active job adapter" do
  include ActiveJob::TestHelper

  around do |example|
    previous_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    ActionMailer::Base.deliveries.clear

    example.run
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActionMailer::Base.deliveries.clear
    ActiveJob::Base.queue_adapter = previous_queue_adapter
  end
end
