module Foundation
  class LogSanitizer
    SENSITIVE_KEYS = %w[
      password senha token api_key authorization prompt prompt_completo
      check_in check_in_bruto neurodivergencia identificacoes_neurodivergentes
      energia energia_individual financial_payload card_number cvv cpf cnpj
      bearer cookie session webhook_signature resposta_livre mood humor
      task event title titulo context contexto external_ref response resposta
    ].freeze

    REDACTED = "[REDACTED]".freeze
    SENSITIVE_STRING_PATTERNS = [
      /bearer\s+[a-z0-9._-]+/i,
      /orb_session_[a-f0-9]+/i,
      /api[_-]?key\s*[:=]\s*[^,\s]+/i,
      /prompt[_\s-]?completo\s*[:=]/i
    ].freeze

    def self.redact(value)
      case value
      when ActionController::Parameters
        redact(value.to_unsafe_h)
      when Hash
        value.each_with_object({}) do |(key, item), redacted|
          redacted[key] = sensitive_key?(key) ? REDACTED : redact(item)
        end
      when Array
        value.map { |item| redact(item) }
      when String
        redact_string(value)
      else
        value
      end
    end

    def self.sensitive_key?(key)
      normalized = key.to_s.downcase
      SENSITIVE_KEYS.any? { |sensitive| normalized.include?(sensitive) }
    end

    def self.redact_string(value)
      SENSITIVE_STRING_PATTERNS.reduce(value.dup) do |memo, pattern|
        memo.gsub(pattern, REDACTED)
      end
    end
  end
end
