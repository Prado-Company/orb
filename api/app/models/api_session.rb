class ApiSession < ApplicationRecord
  belongs_to :user

  validates :token_digest, :expires_at, :source, :correlation_id, presence: true
  validates :token_digest, uniqueness: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.digest_token(raw_token)
    Foundation::Digest.sha256(raw_token)
  end

  def self.authenticate(raw_token)
    return if raw_token.blank?

    active.includes(:user).find_by(token_digest: digest_token(raw_token))&.user&.then do |user|
      user.account_status == "active" && user.deleted_at.nil? ? user : nil
    end
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
