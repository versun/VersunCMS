
require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_user_url
    assert_response :success
  end

  test "should get edit" do
    user = users(:one)
    get edit_user_url(user)
    assert_response :success
  end

  test "should update user" do
    user = users(:one)
    patch user_url(user), params: { user: { name: "New Name" } }
    assert_redirected_to root_url
  end
end
