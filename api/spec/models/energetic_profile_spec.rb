require "rails_helper"

RSpec.describe EnergeticProfile, type: :model do
  it "keeps neurodivergence optional and controlled" do
    user = create_user
    profile = user.energetic_profiles.build(
      archetype: "Coruja Estrategica",
      main_goal: "trabalho",
      neurodivergent_identifications: %w[tdah ahsd],
      source: "web"
    )

    expect(profile).to be_valid
  end

  it "rejects free-form neurodivergence values" do
    user = create_user
    profile = user.energetic_profiles.build(
      archetype: "Coruja Estrategica",
      main_goal: "trabalho",
      neurodivergent_identifications: ["texto livre sensivel"],
      source: "web"
    )

    expect(profile).not_to be_valid
    expect(profile.errors[:neurodivergent_identifications]).to be_present
  end

  it "keeps mutually exclusive sensitive answers isolated" do
    user = create_user
    profile = user.energetic_profiles.build(
      archetype: "Explorador Versatil",
      main_goal: "rotina_geral",
      neurodivergent_identifications: %w[prefiro_nao_dizer tdah],
      source: "web"
    )

    expect(profile).not_to be_valid
    expect(profile.errors[:neurodivergent_identifications]).to be_present
  end
end
