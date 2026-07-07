class AddEncryptionSecretToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :encryption_secret, :string
  end
end
