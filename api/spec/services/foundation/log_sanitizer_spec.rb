require "rails_helper"

RSpec.describe Foundation::LogSanitizer do
  it "redacts sensitive keys recursively and case-insensitively" do
    payload = {
      "Authorization" => "Bearer secret",
      nested: {
        "Prompt_Completo" => "conte tudo",
        check_in_bruto: "estou exausta"
      },
      safe: "ok"
    }

    expect(described_class.redact(payload)).to eq(
      "Authorization" => "[REDACTED]",
      nested: {
        "Prompt_Completo" => "[REDACTED]",
        check_in_bruto: "[REDACTED]"
      },
      safe: "ok"
    )
  end

  it "redacts session tokens inside strings" do
    text = "Authorization: Bearer abc.def and cookie orb_session_abcdef123456"

    expect(described_class.redact(text)).to include("[REDACTED]")
    expect(described_class.redact(text)).not_to include("abc.def", "orb_session_abcdef123456")
  end
end
