class NeurodivergenceUsePolicy
  ALLOWED_USE_CASES = %w[
    personalizacao_acessivel
    tom_e_acessibilidade
    curadoria_regulacao
    exportacao_titular
    tone_adaptation
    explanation_depth
    accessibility_preferences
    regulation_curation
  ].freeze

  PROHIBITED_USE_CASES = %w[
    preco
    pricing
    acesso
    entitlement
    plan_entitlement
    feature_access
    ranking
    next_action_ranking
    terceiros
    third_party
    third_party_payload
    segmentacao_comercial_sensivel
    publicidade_sensivel
    sensitive_ads
    admin_casual_view
    raw_llm_prompt
    billing
    manager_decision
  ].freeze

  def self.allowed?(use_case)
    new(use_case: use_case).allowed?
  end

  def self.prohibited?(use_case)
    new(use_case: use_case).prohibited?
  end

  def initialize(use_case:)
    @use_case = use_case.to_s
  end

  def allowed?
    ALLOWED_USE_CASES.include?(use_case) && !prohibited?
  end

  def prohibited?
    PROHIBITED_USE_CASES.include?(use_case)
  end

  private

  attr_reader :use_case
end
