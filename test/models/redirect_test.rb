require "test_helper"

class RedirectTest < ActiveSupport::TestCase
  test "should validate presence of regex" do
    redirect = Redirect.new(replacement: "/new-path")
    assert_not redirect.valid?
    assert_includes redirect.errors[:regex], "can't be blank"
  end

  test "should validate presence of replacement" do
    redirect = Redirect.new(regex: "^/old-path$")
    assert_not redirect.valid?
    assert_includes redirect.errors[:replacement], "can't be blank"
  end

  test "should validate valid regex pattern" do
    redirect = Redirect.new(regex: "^/valid-path$", replacement: "/new-path")
    assert redirect.valid?
  end

  test "should reject invalid regex pattern" do
    redirect = Redirect.new(regex: "[invalid(regex", replacement: "/new-path")
    assert_not redirect.valid?
    assert_includes redirect.errors[:regex].join, "not a valid regular expression"
  end

  test "should match path with simple regex" do
    redirect = Redirect.create!(regex: "^/old-page$", replacement: "/new-page", enabled: true)
    assert redirect.match?("/old-page")
    assert_not redirect.match?("/old-page/extra")
    assert_not redirect.match?("/other-page")
  end

  test "should match path with capture groups" do
    redirect = Redirect.create!(regex: "^/posts/(.+)$", replacement: "/articles/\\1", enabled: true)
    assert redirect.match?("/posts/test-slug")
    assert redirect.match?("/posts/another-slug")
    assert_not redirect.match?("/posts")
  end

  test "should apply replacement to matched path" do
    redirect = Redirect.create!(regex: "^/old-page$", replacement: "/new-page", enabled: true)
    assert_equal "/new-page", redirect.apply_to("/old-page")
  end

  test "should apply replacement with capture groups" do
    redirect = Redirect.create!(regex: "^/posts/(.+)$", replacement: "/articles/\\1", enabled: true)
    assert_equal "/articles/test-slug", redirect.apply_to("/posts/test-slug")
  end

  test "should return nil for non-matching path" do
    redirect = Redirect.create!(regex: "^/old-page$", replacement: "/new-page", enabled: true)
    assert_nil redirect.apply_to("/other-page")
  end

  test "should not match when disabled" do
    redirect = Redirect.create!(regex: "^/old-page$", replacement: "/new-page", enabled: false)
    assert_not redirect.match?("/old-page")
  end

  test "enabled scope should only return enabled redirects" do
    Redirect.create!(regex: "^/enabled$", replacement: "/new", enabled: true)
    Redirect.create!(regex: "^/disabled$", replacement: "/new", enabled: false)

    enabled_redirects = Redirect.enabled
    assert_equal 1, enabled_redirects.count
    assert enabled_redirects.first.enabled?
  end

  test "should default to temporary redirect" do
    redirect = Redirect.create!(regex: "^/test$", replacement: "/new")
    assert_not redirect.permanent?
  end

  test "should default to enabled" do
    redirect = Redirect.create!(regex: "^/test$", replacement: "/new")
    assert redirect.enabled?
  end
end
