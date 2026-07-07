require "test_helper"

class ContactTest < ActiveSupport::TestCase
  test "favorites are hard-capped at six" do
    provision_tenant.switch do
      contacts = 7.times.map { |i| Contact.create!(handle: "+1555000000#{i}") }
      contacts.first(6).each(&:favorite!)

      assert_raises Contact::FavoritesFull do
        contacts.last.favorite!
      end

      contacts.first.unfavorite!
      assert_nothing_raised { contacts.last.favorite! }
      assert_equal 6, Contact.favorites.count
    end
  end

  test "favoriting is idempotent for an already-pinned contact" do
    provision_tenant.switch do
      6.times { |i| Contact.create!(handle: "+1555111000#{i}").favorite! }

      pinned = Contact.favorites.first
      assert_nothing_raised { pinned.favorite! }
      assert_equal 6, Contact.favorites.count
    end
  end

  test "reordering favorites persists the new positions" do
    provision_tenant.switch do
      contacts = 3.times.map { |i| Contact.create!(handle: "+1555222000#{i}").tap(&:favorite!) }

      Contact.reorder_favorites([ contacts[2].id, contacts[0].id, contacts[1].id ])

      assert_equal [ contacts[2], contacts[0], contacts[1] ], Contact.favorites.to_a
      assert_equal [ 0, 1, 2 ], Contact.favorites.map(&:favorite_position)
    end
  end
end
