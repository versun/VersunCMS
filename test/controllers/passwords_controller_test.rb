
require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_password_url
    assert_response :success
  end

  test "should get edit with valid token" do
    user = users(:one)
    get edit_password_url(token: "valid_token", email: user.email)
    assert_response :success
  end
end
