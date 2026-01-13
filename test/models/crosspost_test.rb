require "test_helper"

class CrosspostTest < ActiveSupport::TestCase
  test "server_url must be http(s)" do
    crosspost = build_crosspost("file:///etc/passwd")

    assert_not crosspost.valid?
    assert_includes crosspost.errors[:server_url], "must be a valid http(s) URL"
  end

  test "server_url allows https urls" do
    crosspost = build_crosspost("https://mastodon.social")

    assert crosspost.valid?
  end

  test "server_url allows https urls with subpaths" do
    crosspost = build_crosspost("https://mastodon.social/masto")

    assert crosspost.valid?
  end

  test "server_url allows leading and trailing whitespace" do
    crosspost = build_crosspost(" https://mastodon.social ")

    assert crosspost.valid?
  end

  test "uses platform defaults for max characters and enforces credentials when enabled" do
    mastodon = Crosspost.new(platform: "mastodon", enabled: false)
    twitter = Crosspost.new(platform: "twitter", enabled: false, max_characters: 111)
    bluesky = Crosspost.new(platform: "bluesky", enabled: false)
    xiaohongshu = Crosspost.new(platform: "xiaohongshu", enabled: false)

    assert_equal 500, mastodon.default_max_characters
    assert_equal 250, twitter.default_max_characters
    assert_equal 300, bluesky.default_max_characters
    assert_equal 300, xiaohongshu.default_max_characters
    assert_equal 111, twitter.effective_max_characters
    assert_equal 500, mastodon.effective_max_characters

    mastodon.enabled = true
    assert_not mastodon.valid?
    assert_includes mastodon.errors[:client_key], "can't be blank"

    xiaohongshu.enabled = true
    assert xiaohongshu.valid?
  end

  private

  def build_crosspost(server_url)
    crosspost = Crosspost.mastodon
    crosspost.assign_attributes(server_url: server_url, enabled: false)
    crosspost
  end
end
