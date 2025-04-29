
require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_session_url
    assert_response :success
  end

  test "should create session with valid credentials" do
    user = users(:one)
    post session_url, params: { email: user.email, password: "password" }
    assert_redirected_to root_url
  end

  test "should fail to create session with invalid credentials" do
    post session_url, params: { email: "invalid@example.com", password: "wrong" }
    assert_response :unprocessable_entity
  end
end
