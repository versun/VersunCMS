require "test_helper"

class ActivityLogTest < ActiveSupport::TestCase
  test "track_activity returns most recent 10 for target and enum is defined" do
    assert_includes ActivityLog.levels.keys, "info"

    12.times do |index|
      timestamp = Time.current - index.minutes
      ActivityLog.create!(
        action: "event-#{index}",
        target: "import",
        level: :info,
        created_at: timestamp,
        updated_at: timestamp
      )
    end

    results = ActivityLog.track_activity("import")
    assert_equal 10, results.size
    assert results.each_cons(2).all? { |a, b| a.created_at >= b.created_at }
  end
end
