require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Helper method to sign in a user in system tests
  def sign_in(user)
    visit new_session_path
    fill_in "User name", with: user.user_name
    fill_in "Password", with: "password123"
    click_button "Sign in"
  end
end
