class User < ApplicationRecord
  ONBOARDING_STATES = %w[nao_iniciado em_andamento pulado concluido revisao_solicitada].freeze
  MINIMUM_PASSWORD_LENGTH = 12
  COMMON_WEAK_PASSWORDS = %w[
    1234
    123456
    12345678
    password
    senha
    senha123
    qwerty
  ].freeze

  has_many :api_sessions, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :energetic_profiles, dependent: :destroy
  has_many :check_ins, dependent: :destroy
  has_many :energies, dependent: :destroy
  has_many :suggestions, dependent: :destroy
  has_many :interventions, dependent: :destroy
  has_many :plan_entitlements, dependent: :destroy
  has_many :data_export_requests, dependent: :destroy
  has_many :data_deletion_requests, dependent: :destroy

  before_validation :normalize_email

  validates :name, :email, :password_digest, :timezone, :locale, :plan, :account_status, presence: true
  validates :email, uniqueness: { case_sensitive: false }
  validates :plan, inclusion: { in: %w[free pro teams] }
  validates :account_status, inclusion: { in: %w[active suspended soft_deleted deleted] }
  validates :onboarding_state, inclusion: { in: ONBOARDING_STATES }

  scope :active, -> { where(account_status: "active", deleted_at: nil) }

  def self.authenticate(email:, password:)
    user = active.find_by(email: email.to_s.strip.downcase)
    return unless user&.authenticate_password(password)

    user
  end

  def password=(raw_password)
    issues = self.class.password_strength_issues(raw_password)
    raise ArgumentError, "password_required" if issues.include?("required")
    raise ArgumentError, "password_too_weak" if issues.any?

    self.password_digest = Foundation::PasswordHasher.digest(raw_password)
  end

  def authenticate_password(raw_password)
    Foundation::PasswordHasher.verify(raw_password, password_digest)
  end

  def self.password_strength_issues(raw_password)
    password = raw_password.to_s
    return ["required"] if password.blank?

    issues = []
    normalized = password.downcase
    issues << "too_short" if password.length < MINIMUM_PASSWORD_LENGTH
    issues << "missing_letter" unless password.match?(/[[:alpha:]]/)
    issues << "missing_number" unless password.match?(/\d/)
    issues << "common_password" if COMMON_WEAK_PASSWORDS.include?(normalized)
    issues
  end

  def issue_session!(source:, correlation_id:, ip_address: nil, user_agent: nil)
    raw_token = "orb_session_#{SecureRandom.hex(32)}"
    session = api_sessions.create!(
      token_digest: ApiSession.digest_token(raw_token),
      expires_at: 30.days.from_now,
      source: source,
      correlation_id: correlation_id,
      ip_hash: Foundation::Digest.fingerprint(ip_address),
      user_agent_hash: Foundation::Digest.fingerprint(user_agent)
    )

    [raw_token, session]
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
