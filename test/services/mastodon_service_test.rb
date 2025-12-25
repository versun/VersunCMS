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
end
