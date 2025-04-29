
require "test_helper"

class Tools::ImportControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get tools_import_index_url
    assert_response :success
  end

  test "should import from rss" do
    post from_rss_tools_import_index_url, params: { rss_url: "http://example.com/rss" }
    assert_redirected_to tools_import_index_url
  end
end
