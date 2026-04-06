require "digest"

module RateLimitable
  private

  def throttle!(bucket:, limit:, period:, scope: nil)
    discriminator = [ request.remote_ip, scope.presence || "global" ].join(":")
    result = ApiRateLimiter.check(
      bucket: bucket,
      discriminator: discriminator,
      limit: limit,
      period: period
    )
    return if result.allowed?

    response.set_header("Retry-After", result.retry_after.to_s)
    AppEventLogger.warn(
      "auth.rate_limited",
      **request_context(
        bucket: bucket,
        retry_after: result.retry_after,
        scope_digest: Digest::SHA256.hexdigest(scope.to_s.presence || "global")
      )
    )

    render_error(
      code: "rate_limited",
      message: "Too many requests. Try again later.",
      status: :too_many_requests,
      meta: { retry_after: result.retry_after }
    )
  end

  def normalized_email_param
    params[:email].to_s.strip.downcase
  end
end
