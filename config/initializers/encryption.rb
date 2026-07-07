# Encrypted attributes get their keys per tenant through Tenant::KeyProvider,
# so no global primary key is configured here. The derivation salt is shared;
# secrets are not.
Rails.application.config.active_record.encryption.key_derivation_salt =
  ENV.fetch("IKEEP_KEY_DERIVATION_SALT") { Rails.application.secret_key_base }
