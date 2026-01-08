require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "sets Content-Security-Policy header on public pages" do
    get root_path

    assert_response :success
    policy = response.headers["Content-Security-Policy"]

    assert policy.present?, "expected Content-Security-Policy header to be set"
    assert_includes policy, "default-src"
  end
end
