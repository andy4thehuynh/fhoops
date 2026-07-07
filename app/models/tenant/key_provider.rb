# The KeyProvider seam. Encrypted attributes on tenant models declare
# `key_provider: Tenant::KeyProvider.new`; at run time every operation
# delegates to the key provider of whichever tenant is currently switched
# in, so ciphertext written for one tenant can never be read with another
# tenant's key. A future zero-knowledge mode only needs to change where
# Tenant#encryption_secret comes from.
class Tenant::KeyProvider
  def encryption_key
    current.encryption_key
  end

  def decryption_keys(encrypted_message)
    current.decryption_keys(encrypted_message)
  end

  private
    def current
      tenant = Current.tenant or raise ActiveRecord::Encryption::Errors::Configuration, "No tenant switched in — encrypted attributes require Tenant#switch"
      tenant.encryption_key_provider
    end
end
