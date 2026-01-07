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

  private

  def build_crosspost(server_url)
    crosspost = Crosspost.mastodon
    crosspost.assign_attributes(server_url: server_url, enabled: false)
    crosspost
  end
end
