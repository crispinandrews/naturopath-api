class ExceptionReporter
  class << self
    def report(exception, context: {})
      Rails.error.report(exception, handled: true, context: context)

      AppEventLogger.error(
        "api.internal_error",
        exception_class: exception.class.name,
        message: exception.message,
        backtrace: exception.backtrace&.first(5),
        **context
      )
    end
  end
end
