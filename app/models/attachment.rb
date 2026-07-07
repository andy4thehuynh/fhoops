class Attachment < TenantRecord
  belongs_to :message

  encrypts :path, key_provider: Tenant::KeyProvider.new
end
