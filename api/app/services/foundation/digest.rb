require "openssl"

module Foundation
  module Digest
    module_function

    def sha256(value)
      return if value.blank?

      OpenSSL::Digest::SHA256.hexdigest(value.to_s)
    end

    def fingerprint(value)
      sha256(value)&.first(24)
    end
  end
end
