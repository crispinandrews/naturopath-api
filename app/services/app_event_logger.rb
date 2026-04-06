class AppEventLogger
  class << self
    def info(event, **context)
      log(:info, event, context)
    end

    def warn(event, **context)
      log(:warn, event, context)
    end

    def error(event, **context)
      log(:error, event, context)
    end

    private

    def log(level, event, context)
      payload = {
        event: event,
        at: Time.current.iso8601(3)
      }.merge(context.compact)

      Rails.logger.public_send(level, payload.to_json)
      ActiveSupport::Notifications.instrument("app_event.naturopath_api", payload)
    end
  end
end
