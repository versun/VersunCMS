
require "test_helper"

class NewslettersControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    get newsletter_url
    assert_response :success
  end

  test "should update newsletter" do
    patch update_newsletter_url, params: { listmonk: { endpoint: "http://example.com" } }
    assert_redirected_to newsletter_url
  end
end
