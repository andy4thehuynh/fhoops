# Every model that lives inside a tenant's own SQLite database inherits from
# this class instead of ApplicationRecord. It carries no connection of its own:
# Tenant#switch registers one pool per tenant database, keyed by shard, and
# anything touching a TenantRecord outside a switch raises — by design, so no
# code path can accidentally read the wrong tenant.
class TenantRecord < ActiveRecord::Base
  self.abstract_class = true

  # Tenant databases are registered at runtime (one shard per tenant), not
  # through connects_to/database.yml, so mark this class as connection-owning
  # ourselves — connected_to refuses to swap shards otherwise, and pool
  # lookups would fall through to ActiveRecord::Base's primary database.
  self.connection_class = true
  self.connection_specification_name = name
end
