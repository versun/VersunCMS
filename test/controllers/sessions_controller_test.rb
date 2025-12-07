require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:admin)
  end

  test "should get new" do
    get new_session_path
    assert_response :success
  end

  test "should create session with valid credentials" do
    post sessions_path, params: {
      session: {
        user_name: @user.user_name,
        password: "password123"
      }
    }

    assert_redirected_to root_path
  end

  test "should not create session with invalid username" do
    post sessions_path, params: {
      session: {
        user_name: "nonexistent",
        password: "password123"
      }
    }

    assert_response :unprocessable_entity
  end

  test "should not create session with invalid password" do
    post sessions_path, params: {
      session: {
        user_name: @user.user_name,
        password: "wrongpassword"
      }
    }

    assert_response :unprocessable_entity
  end

  test "should destroy session" do
    sign_in(@user)

    delete session_path(@user.sessions.first.id)
    assert_redirected_to root_path
  end
end
