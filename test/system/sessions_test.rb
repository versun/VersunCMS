require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  def setup
    @user = users(:admin)
  end

  test "signing in with valid credentials" do
    visit new_session_path

    fill_in "User name", with: @user.user_name
    fill_in "Password", with: "password123"
    click_button "Sign in"

    assert_text "Signed in successfully"
    assert_current_path admin_root_path
  end

  test "signing in with invalid credentials" do
    visit new_session_path

    fill_in "User name", with: @user.user_name
    fill_in "Password", with: "wrongpassword"
    click_button "Sign in"

    assert_text "Invalid user name or password"
  end

  test "signing out" do
    sign_in(@user)
    visit admin_root_path

    click_link "Sign out"

    assert_current_path root_path
  end
end

