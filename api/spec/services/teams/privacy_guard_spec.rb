require "rails_helper"

RSpec.describe Teams::PrivacyGuard do
  it "blocks sensitive individual resources in organization context" do
    expect do
      described_class.ensure_individual_access!(resource_type: "energy", org_context: true)
    end.to raise_error(Teams::SensitiveIndividualAccessBlocked)
  end

  it "requires at least three people for sensitive aggregates" do
    expect(described_class.aggregate_allowed?(2)).to be(false)
    expect(described_class.aggregate_allowed?(3)).to be(true)
  end
end
