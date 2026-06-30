require "rails_helper"

RSpec.describe NeurodivergenceUsePolicy do
  it "allows only inclusive personalization and accessibility use cases" do
    expect(described_class.allowed?("personalizacao_acessivel")).to be(true)
    expect(described_class.allowed?("tone_adaptation")).to be(true)
    expect(described_class.allowed?("accessibility_preferences")).to be(true)
    expect(described_class.allowed?("regulation_curation")).to be(true)
  end

  it "blocks price, access, ranking, third-party, billing and raw prompt use cases" do
    prohibited = %w[
      preco
      pricing
      acesso
      plan_entitlement
      feature_access
      ranking
      next_action_ranking
      terceiros
      third_party_payload
      sensitive_ads
      admin_casual_view
      raw_llm_prompt
      billing
      manager_decision
    ]

    prohibited.each do |use_case|
      expect(described_class.prohibited?(use_case)).to be(true)
      expect(described_class.allowed?(use_case)).to be(false)
    end
  end

  it "denies unknown use cases by default" do
    expect(described_class.allowed?("experimento_futuro")).to be(false)
  end
end
