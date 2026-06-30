require Rails.root.join("app/services/foundation/job_registry").to_s

Rails.application.config.active_job.queue_adapter = :solid_queue

ORB_SOLID_QUEUE_REGISTRY = Foundation::JobRegistry::QUEUES
