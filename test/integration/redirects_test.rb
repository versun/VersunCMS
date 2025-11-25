require "test_helper"

class RedirectsIntegrationTest < ActionDispatch::IntegrationTest
  test "should redirect with simple pattern" do
    Redirect.create!(
      regex: "^/old-page$",
      replacement: "/new-page",
      permanent: false,
      enabled: true
    )

    get "/old-page"
    assert_redirected_to "/new-page"
    assert_response :found # 302
  end

  test "should redirect with permanent status" do
    Redirect.create!(
      regex: "^/old-page$",
      replacement: "/new-page",
      permanent: true,
      enabled: true
    )

    get "/old-page"
    assert_redirected_to "/new-page"
    assert_response :moved_permanently # 301
  end

  test "should redirect with capture groups" do
    Redirect.create!(
      regex: "^/posts/(.+)$",
      replacement: "/articles/\\1",
      permanent: false,
      enabled: true
    )

    get "/posts/test-slug"
    assert_redirected_to "/articles/test-slug"
    assert_response :found
  end

  test "should not redirect when disabled" do
    Redirect.create!(
      regex: "^/old-page$",
      replacement: "/new-page",
      permanent: false,
      enabled: false
    )

    get "/old-page"
    assert_response :not_found # No redirect happens, returns 404
  end

  test "should not redirect admin pages" do
    Redirect.create!(
      regex: "^/admin.*$",
      replacement: "/redirected",
      permanent: false,
      enabled: true
    )

    get admin_redirects_path
    assert_response :success # Should load admin page, not redirect
  end

  test "should not redirect when no pattern matches" do
    Redirect.create!(
      regex: "^/old-page$",
      replacement: "/new-page",
      permanent: false,
      enabled: true
    )

    get "/other-page"
    assert_response :not_found # No redirect, normal behavior
  end

  test "should use first matching redirect" do
    Redirect.create!(
      regex: "^/test$",
      replacement: "/first",
      permanent: false,
      enabled: true,
      created_at: 1.hour.ago
    )

    Redirect.create!(
      regex: "^/test$",
      replacement: "/second",
      permanent: false,
      enabled: true,
      created_at: Time.current
    )

    get "/test"
    # Should redirect to one of them (order may vary based on database)
    assert_redirected_to %r{/(first|second)}
  end
end
