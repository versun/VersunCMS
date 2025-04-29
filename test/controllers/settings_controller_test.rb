
require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    get edit_setting_url
    assert_response :success
  end

  test "should update settings" do
    patch setting_url, params: { setting: { site_name: "New Site Name" } }
    assert_redirected_to edit_setting_url
  end
end
