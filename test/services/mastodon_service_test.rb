require "test_helper"

class MastodonServiceTest < ActiveSupport::TestCase
  test "verify fails fast when access token is blank" do
    service = MastodonService.new
    result = service.verify({})

    assert_equal false, result[:success]
    assert_match "Access token", result[:error]
  end

  test "post returns nil when crosspost is disabled" do
    Crosspost.mastodon.update!(enabled: false)
    service = MastodonService.new

    assert_nil service.post(create_published_article)
  end

  test "mastodon api uri preserves server subpaths" do
    service = MastodonService.new

    uri = service.send(:mastodon_api_uri, "/api/v1/statuses", "https://example.com/masto")

    assert_equal "https://example.com/masto/api/v1/statuses", uri.to_s
  end
end
