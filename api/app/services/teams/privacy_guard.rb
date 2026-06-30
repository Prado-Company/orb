module Teams
  class PrivacyGuard
    SENSITIVE_INDIVIDUAL_RESOURCES = %w[
      energy energia check_in energetic_profile perfil_energetico intervention intervencao
    ].freeze

    MINIMUM_AGGREGATE_SIZE = 3

    def self.allow_individual_access?(resource_type:, org_context:)
      return true unless org_context

      !SENSITIVE_INDIVIDUAL_RESOURCES.include?(resource_type.to_s)
    end

    def self.ensure_individual_access!(resource_type:, org_context:)
      return true if allow_individual_access?(resource_type: resource_type, org_context: org_context)

      raise SensitiveIndividualAccessBlocked
    end

    def self.aggregate_allowed?(member_count)
      member_count.to_i >= MINIMUM_AGGREGATE_SIZE
    end
  end
end
