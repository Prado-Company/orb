require "base64"
require "openssl"

module Foundation
  class PasswordHasher
    ITERATIONS = 65_536
    BYTE_LENGTH = 32
    PREFIX = "pbkdf2_sha256".freeze

    def self.digest(raw_password)
      password = raw_password.to_s
      raise ArgumentError, "password_required" if password.blank?

      salt = SecureRandom.hex(16)
      hash = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, ITERATIONS, BYTE_LENGTH, OpenSSL::Digest::SHA256.new)
      "#{PREFIX}$#{ITERATIONS}$#{salt}$#{Base64.strict_encode64(hash)}"
    end

    def self.verify(raw_password, encoded_digest)
      prefix, iterations, salt, expected = encoded_digest.to_s.split("$", 4)
      return false unless prefix == PREFIX && iterations.present? && salt.present? && expected.present?

      actual = OpenSSL::PKCS5.pbkdf2_hmac(
        raw_password.to_s,
        salt,
        iterations.to_i,
        BYTE_LENGTH,
        OpenSSL::Digest::SHA256.new
      )

      ActiveSupport::SecurityUtils.secure_compare(
        Base64.strict_encode64(actual),
        expected
      )
    rescue ArgumentError
      false
    end
  end
end
