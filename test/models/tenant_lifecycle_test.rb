require "test_helper"

class TenantLifecycleTest < ActiveSupport::TestCase
  test "purging a tenant removes only that tenant's file and registry row" do
    keep = provision_tenant
    goner = Tenant.provision("goner#{SecureRandom.hex(4)}")
    goner_path = goner.database_path

    assert goner_path.exist?
    goner.purge!

    assert_not goner_path.exist?
    assert_not Tenant.exists?(name: goner.name)
    assert keep.database_path.exist?
    keep.switch { assert_equal 0, Message.count } # still connectable
  end
end
