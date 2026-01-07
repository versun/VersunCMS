require "test_helper"

class CrosspostTest < ActiveSupport::TestCase
  test "server_url must be http(s)" do
    crosspost = Crosspost.new(platform: "mastodon", server_url: "file:///etc/passwd")

    assert_not crosspost.valid?
    assert_includes crosspost.errors[:server_url], "must be a valid http(s) URL"
  end

  test "server_url allows https urls" do
    crosspost = Crosspost.new(platform: "mastodon", server_url: "https://mastodon.social")

    assert crosspost.valid?
  end

  test "server_url allows https urls with subpaths" do
    crosspost = Crosspost.new(platform: "mastodon", server_url: "https://mastodon.social/masto")

    assert crosspost.valid?
  end

  test "server_url allows leading and trailing whitespace" do
    crosspost = Crosspost.new(platform: "mastodon", server_url: " https://mastodon.social ")

    assert crosspost.valid?
  end
end
