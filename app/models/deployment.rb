# iKeep runs in one of two modes, chosen by DEPLOYMENT_MODE:
#
#   self_host (default) — exactly one tenant, encryption key kept on the box
#     via ENV or Rails credentials.
#   hosted — many tenants, each with its own server-held encryption key.
#     Convenience-grade: the operator can decrypt. See README for the honest
#     privacy guarantees of each mode.
module Deployment
  class << self
    def mode
      ENV.fetch("DEPLOYMENT_MODE", "self_host").to_sym
    end

    def hosted?
      mode == :hosted
    end

    def self_host?
      !hosted?
    end

    # The single key used by self_host mode. In production it must be set
    # explicitly so it can live outside the data disk (ENV, credentials, or
    # injected from the macOS Keychain by your process manager).
    def host_encryption_secret
      ENV["IKEEP_ENCRYPTION_SECRET"] ||
        Rails.application.credentials.dig(:ikeep, :encryption_secret) ||
        (Rails.env.production? ? raise("Set IKEEP_ENCRYPTION_SECRET (or credentials ikeep.encryption_secret) in production") : Rails.application.secret_key_base)
    end
  end
end
