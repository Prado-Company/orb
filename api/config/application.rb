require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module OrbApi
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true

    config.active_job.queue_adapter = :solid_queue
    config.autoload_paths << root.join("app/services")
    config.eager_load_paths << root.join("app/services")

    config.filter_parameters += [
      :password,
      :token,
      :api_key,
      :authorization,
      :prompt,
      :prompt_completo,
      :check_in,
      :check_in_bruto,
      :neurodivergencia,
      :identificacoes_neurodivergentes,
      :energia
    ]
  end
end
