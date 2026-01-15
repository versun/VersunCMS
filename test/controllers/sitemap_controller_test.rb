require "test_helper"

class SitemapControllerTest < ActionDispatch::IntegrationTest
  test "sitemap returns xml" do
    get sitemap_path(format: :xml)
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
    assert_includes response.body, "<urlset"
  end
end
