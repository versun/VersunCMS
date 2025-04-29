
require "test_helper"

class SitemapControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get sitemap_url(format: :xml)
    assert_response :success
    assert_equal "application/xml", @response.media_type
  end
end
