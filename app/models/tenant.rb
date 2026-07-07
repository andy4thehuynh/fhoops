# The tenant registry. This is the only table in the shared app database —
# message content never lives here. Each tenant is a single SQLite file under
# Tenant.storage_root, so exporting or deleting a tenant is copying or
# deleting one file.
class Tenant < ApplicationRecord
  validates :name, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9][a-z0-9_-]*\z/, message: "must be lowercase letters, digits, dashes or underscores" }

  before_create { self[:encryption_secret] ||= SecureRandom.hex(32) }

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
  # resolve their connection through the shard registered here, and
  # encrypted attributes pick up this tenant's key via Current.tenant.
  def switch(&block)
    connect
    previous, Current.tenant = Current.tenant, self
    TenantRecord.connected_to(shard: shard, &block)
  ensure
    Current.tenant = previous
  end

  # Rails' Migrator always runs DDL on ActiveRecord::Base's pool, which is
  # the app database — repointing it (what db:migrate does for secondary
  # databases) would clobber in-flight connections. So tenant migrations run
  # directly on this tenant's own connection, with versions tracked in the
  # tenant's schema_migrations table.
  def prepare
    switch do
      pool = TenantRecord.connection_pool
      schema = pool.schema_migration
      schema.create_table
      applied = schema.versions.map(&:to_i)

      pool.with_connection do |connection|
        Dir[Rails.root.join("db/tenant_migrate/[0-9]*_*.rb").to_s].sort.each do |file|
          version, name = File.basename(file, ".rb").split("_", 2)
          next if applied.include?(version.to_i)

          require file
          name.camelize.constantize.new.exec_migration(connection, :up)
          schema.create_version(version)
        end
      end
    end
  end

  def database_path
    self.class.storage_root.join("#{name}.sqlite3")
  end

  # In self_host mode every tenant (there is only one) encrypts with the
  # host key, kept off the data disk. In hosted mode each tenant has its
  # own server-held key, so tenants can be exported or deleted key-and-all,
  # and one tenant's ciphertext is useless against another's key.
  def encryption_secret
    Deployment.hosted? ? super : Deployment.host_encryption_secret
  end

  def encryption_key_provider
    @encryption_key_provider ||= ActiveRecord::Encryption::DerivedSecretKeyProvider.new(encryption_secret)
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
        pool: ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i,
        timeout: 5000
      }
    end
end
