module Foundation
  class JobRegistry
    QUEUES = {
      billing: {
        adapter: "SolidQueue",
        queue_name: "billing",
        retry_on: "StandardError",
        attempts: 5,
        idempotency_key: "billing:event_id",
        requires_correlation_id: true
      },
      lgpd: {
        adapter: "SolidQueue",
        queue_name: "lgpd",
        retry_on: "StandardError",
        attempts: 5,
        idempotency_key: "lgpd:request_id",
        requires_correlation_id: true
      },
      notifications: {
        adapter: "SolidQueue",
        queue_name: "notifications",
        retry_on: "StandardError",
        attempts: 3,
        idempotency_key: "notification:delivery_id",
        requires_correlation_id: true
      },
      insights: {
        adapter: "SolidQueue",
        queue_name: "insights",
        retry_on: "StandardError",
        attempts: 3,
        idempotency_key: "insight:user_period",
        requires_correlation_id: true
      },
      ml_batch: {
        adapter: "SolidQueue",
        queue_name: "ml_batch",
        retry_on: "StandardError",
        attempts: 3,
        idempotency_key: "ml_batch:period",
        requires_correlation_id: true
      },
      exports: {
        adapter: "SolidQueue",
        queue_name: "exports",
        retry_on: "StandardError",
        attempts: 5,
        idempotency_key: "export:request_id",
        requires_correlation_id: true
      },
      maintenance: {
        adapter: "SolidQueue",
        queue_name: "maintenance",
        retry_on: "StandardError",
        attempts: 2,
        idempotency_key: "maintenance:task_id",
        requires_correlation_id: true
      }
    }.freeze
  end
end
