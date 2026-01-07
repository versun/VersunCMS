require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  test "setup requires site url" do
    User.delete_all
    Setting.delete_all

    post setup_path, params: {
      user: {
        user_name: "admin",
        password: "password123",
        password_confirmation: "password123"
      },
      setting: {
        title: "Test Site",
        url: ""
      }
    }

    assert_response :unprocessable_entity
    assert_match(/Url can't be blank/, response.body)
  end
end
