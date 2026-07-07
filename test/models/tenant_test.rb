require "test_helper"

class TenantTest < ActiveSupport::TestCase
  test "requires a well-formed name" do
    assert_not Tenant.new(name: "").valid?
    assert_not Tenant.new(name: "No Spaces!").valid?
    assert Tenant.new(name: "andy-2").valid?
  end

  test "name is unique" do
    tenant = provision_tenant
    assert_not Tenant.new(name: tenant.name).valid?
  end

  test "provisioning creates the tenant's database file and is idempotent" do
    tenant = provision_tenant
    assert tenant.database_path.exist?

    assert_equal tenant, Tenant.provision(tenant.name)
    assert_equal 1, Tenant.where(name: tenant.name).count
  end

  test "tenant databases run in WAL mode" do
    provision_tenant.switch do
      assert_equal "wal", TenantRecord.lease_connection.select_value("PRAGMA journal_mode")
    end
  end

  test "sqlite-vec answers nearest-neighbor queries inside a tenant database" do
    provision_tenant.switch do
      connection = TenantRecord.lease_connection
      connection.execute("CREATE VIRTUAL TABLE scratch_vectors USING vec0(embedding float[4])")
      connection.execute(<<~SQL)
        INSERT INTO scratch_vectors(rowid, embedding) VALUES
          (1, '[1, 0, 0, 0]'), (2, '[0, 1, 0, 0]'), (3, '[0.9, 0.1, 0, 0]')
      SQL

      nearest = connection.select_values(<<~SQL)
        SELECT rowid FROM scratch_vectors WHERE embedding MATCH '[1, 0, 0, 0]' AND k = 2 ORDER BY distance
      SQL

      assert_equal [ 1, 3 ], nearest
    end
  end

  test "tenants are isolated from each other" do
    one = provision_tenant
    two = provision_tenant

    one.switch do
      connection = TenantRecord.lease_connection
      connection.execute("CREATE TABLE notes (body text)")
      connection.execute("INSERT INTO notes VALUES ('only in tenant one')")
    end

    two.switch do
      assert_not TenantRecord.lease_connection.table_exists?("notes")
    end
  end

  test "tenant records are unreachable outside a switch" do
    provision_tenant

    assert_raises ActiveRecord::ConnectionNotEstablished do
      TenantRecord.lease_connection
    end
  end
end
