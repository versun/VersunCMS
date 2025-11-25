require "test_helper"

class Admin::RedirectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @redirect = Redirect.create!(
      regex: "^/old-path$",
      replacement: "/new-path",
      permanent: false,
      enabled: true
    )
  end

  test "should get index" do
    get admin_redirects_url
    assert_response :success
  end

  test "should get new" do
    get new_admin_redirect_url
    assert_response :success
  end

  test "should create redirect" do
    assert_difference("Redirect.count") do
      post admin_redirects_url, params: {
        redirect: {
          regex: "^/test-path$",
          replacement: "/replacement-path",
          permanent: true,
          enabled: true
        }
      }
    end

    assert_redirected_to admin_redirects_url
    assert_equal "Redirect was successfully created.", flash[:notice]
  end

  test "should not create redirect with invalid regex" do
    assert_no_difference("Redirect.count") do
      post admin_redirects_url, params: {
        redirect: {
          regex: "[invalid(regex",
          replacement: "/replacement-path"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_admin_redirect_url(@redirect)
    assert_response :success
  end

  test "should update redirect" do
    patch admin_redirect_url(@redirect), params: {
      redirect: {
        regex: "^/updated-path$",
        replacement: "/new-updated-path"
      }
    }

    assert_redirected_to admin_redirects_url
    @redirect.reload
    assert_equal "^/updated-path$", @redirect.regex
    assert_equal "/new-updated-path", @redirect.replacement
  end

  test "should destroy redirect" do
    assert_difference("Redirect.count", -1) do
      delete admin_redirect_url(@redirect)
    end

    assert_redirected_to admin_redirects_url
    assert_equal "Redirect was successfully deleted.", flash[:notice]
  end
end
