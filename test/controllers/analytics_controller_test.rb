
require "test_helper"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get analytics_url
    assert_response :success
  end
end
