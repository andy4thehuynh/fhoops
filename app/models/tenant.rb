# The tenant registry. This is the only table in the shared app database —
# message content never lives here. Each tenant is a single SQLite file under
# Tenant.storage_root, so exporting or deleting a tenant is copying or
# deleting one file.
class Tenant < ApplicationRecord
  validates :name, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9][a-z0-9_-]*\z/, message: "must be lowercase letters, digits, dashes or underscores" }

  class << self
    # Registers the tenant (idempotently) and brings its database file
    # into existence, fully migrated.
    def provision(name)
      find_or_create_by!(name: name).tap(&:prepare)
    end

    # self_host mode runs exactly one tenant.
    def default
      sole
    end

    def storage_root
      Rails.root.join("storage/tenants", Rails.env)
    end
  end

  # Runs the block against this tenant's database. All TenantRecord models
  # resolve their connection through the shard registered here.
  def switch(&block)
    connect
    TenantRecord.connected_to(shard: shard, &block)
  end

  def prepare
    switch { TenantRecord.connection_pool.migration_context.migrate }
  end

  def database_path
    self.class.storage_root.join("#{name}.sqlite3")
  end

  private
    def shard
      # Prefixed so no tenant name can collide with Rails' :default shard,
      # which would make the tenant reachable outside a switch block.
      :"tenant_#{name}"
    end

    def connect
      return if TenantRecord.connection_handler.retrieve_connection_pool(TenantRecord.name, role: :writing, shard: shard)

      self.class.storage_root.mkpath
      TenantRecord.connection_handler.establish_connection(
        database_config, owner_name: TenantRecord, role: :writing, shard: shard
      )
    end

    def database_config
      {
        adapter: "sqlite3",
        database: database_path.to_s,
        pragmas: { journal_mode: "wal" },
        extensions: [ SqliteVec.loadable_path ],
        migrations_paths: "db/tenant_migrate",
        pool: ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i,
        timeout: 5000
      }
    end
end
