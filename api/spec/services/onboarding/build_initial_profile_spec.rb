require "rails_helper"

RSpec.describe Onboarding::BuildInitialProfile do
  it "generates the initial archetype with deterministic rules and no LLM dependency" do
    user = create_user(name: "Ana")

    result = described_class.new(
      user: user,
      source: "web",
      responses: {
        objetivo_principal: "trabalho",
        janelas_pico: %w[noite],
        janelas_baixa_energia: %w[depois_do_almoco],
        gatilhos: %w[reunioes_longas],
        sensibilidade: "media"
      }
    ).call

    expect(result.attributes).to include(
      archetype: "Coruja Estrategica",
      main_goal: "trabalho",
      confidence: "media"
    )
    expect(result.payload).to include(
      arquetipo: "Coruja Estrategica",
      confianca_inicial: "media"
    )
  end

  it "uses low-confidence neutral defaults for unknown windows" do
    user = create_user(name: "Bia", email: "bia@example.com")

    result = described_class.new(
      user: user,
      source: "web",
      responses: {
        objetivo_principal: "rotina_geral",
        janelas_pico: %w[ainda_nao_sei]
      }
    ).call

    expect(result.attributes).to include(
      archetype: "Explorador Versatil",
      confidence: "baixa"
    )
  end
end
