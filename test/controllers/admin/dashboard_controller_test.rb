require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Add any necessary setup, like creating a user
  end

  test "should get index" do
    get admin_dashboard_url
    assert_response :success
  end
end