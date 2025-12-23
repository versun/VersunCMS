require "test_helper"

class Services::TwitterServiceTest < ActiveSupport::TestCase
  test "verify fails fast when required fields are blank" do
    service = Services::TwitterService.new
    result = service.verify({})

    assert_equal false, result[:success]
    assert_match "Please fill in all information", result[:error]
  end

  test "post returns nil when crosspost is disabled" do
    Crosspost.twitter.update!(enabled: false)
    service = Services::TwitterService.new

    assert_nil service.post(create_published_article)
  end
end
