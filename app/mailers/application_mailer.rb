class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "no-reply@naturopath.local") }
  layout "mailer"
end
