
require "test_helper"

class Tools::ExportControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get tools_export_index_url
    assert_response :success
  end

  test "should create export" do
    post tools_export_index_url
    assert_response :success
  end
end
