module CorrelationId
  extend ActiveSupport::Concern

  private

  def set_correlation_id
    request_correlation_id
    response.set_header("X-Correlation-ID", @request_correlation_id)
  end

  def request_correlation_id
    @request_correlation_id ||= begin
      header = request.headers["X-Correlation-ID"] || request.headers["X-Correlation-Id"]
      safe_header = header.to_s.strip
      safe_header.match?(/\A[a-zA-Z0-9._:-]{8,120}\z/) ? safe_header : "corr_#{SecureRandom.uuid}"
    end
  end
end
