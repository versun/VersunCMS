
require "test_helper"

class CrosspostsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get crossposts_url
    assert_response :success
  end

  test "should update crosspost" do
    crosspost = crossposts(:one)
    patch crosspost_url(crosspost), params: { crosspost: { enabled: true } }
    assert_redirected_to crossposts_url
  end

  test "should verify crosspost" do
    crosspost = crossposts(:one)
    post verify_crosspost_url(crosspost)
    assert_redirected_to crossposts_url
  end
end
