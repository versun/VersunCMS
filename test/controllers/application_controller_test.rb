
require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "should set time zone" do
    get root_url
    assert_equal CacheableSettings.site_info[:time_zone] || "UTC", Time.zone.name
  end
end
