
require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  test "should get posts" do
    get admin_posts_url
    assert_response :success
  end

  test "should get pages" do
    get admin_pages_url
    assert_response :success
  end
end
