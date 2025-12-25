require "test_helper"

class Admin::NewsletterControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:admin)
    sign_in(@user)
  end

  test "update accepts submit param and redirects" do
    patch admin_newsletter_path, params: {
      newsletter_setting: {
        enabled: "1",
        provider: "native",
        smtp_address: "smtp.example.com",
        smtp_port: "587",
        smtp_user_name: "user",
        smtp_password: "password",
        smtp_domain: "example.com",
        smtp_authentication: "plain",
        smtp_enable_starttls: "1",
        from_email: "noreply@example.com",
        footer: "<p><br></p>",
        submit: "Save Native Email Settings"
      }
    }

    assert_redirected_to admin_newsletter_path
    assert_equal "smtp.example.com", NewsletterSetting.first.smtp_address
  end

  test "update renders show on validation failure without error" do
    patch admin_newsletter_path, params: {
      newsletter_setting: {
        enabled: "1",
        provider: "native",
        smtp_address: "smtp.example.com",
        smtp_port: "587",
        smtp_user_name: "user",
        smtp_password: "password",
        smtp_domain: "example.com",
        smtp_authentication: "plain",
        smtp_enable_starttls: "1",
        from_email: "invalid-email",
        footer: "<p><br></p>",
        submit: "Save Native Email Settings"
      }
    }

    assert_response :unprocessable_entity
    assert_select "h3", text: "Newsletter Settings"
  end

  test "listmonk update failure renders show without error" do
    patch admin_newsletter_path, params: {
      listmonk: {
        url: "not-a-url",
        username: "",
        api_key: ""
      }
    }

    assert_response :unprocessable_entity
    assert_select "h3", text: "Newsletter Settings"
    assert_select "select#list-select"
    assert_select "select#template-select"
  end
end
