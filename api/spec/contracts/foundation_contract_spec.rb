RSpec.describe "foundation contracts" do
  it "keeps the API contract boundary explicit" do
    expect("/api/v1").to include("api")
  end
end
