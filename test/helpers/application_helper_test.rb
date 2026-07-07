require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "succinct timestamps follow the iMessage rules" do
    travel_to Time.zone.local(2026, 7, 7, 12, 0) do # a Tuesday
      assert_equal "9:05 AM", succinct_timestamp(Time.zone.local(2026, 7, 7, 9, 5))
      assert_equal "Yesterday", succinct_timestamp(Time.zone.local(2026, 7, 6, 22, 0))
      assert_equal "Sat", succinct_timestamp(Time.zone.local(2026, 7, 4, 10, 0))
      assert_equal "Mar 3", succinct_timestamp(Time.zone.local(2026, 3, 3, 10, 0))
      assert_equal "Mar 3, 2023", succinct_timestamp(Time.zone.local(2023, 3, 3, 10, 0))
      assert_equal "", succinct_timestamp(nil)
    end
  end
end
