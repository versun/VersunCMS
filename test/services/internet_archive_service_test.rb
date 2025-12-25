require "test_helper"

class InternetArchiveServiceTest < ActiveSupport::TestCase
  test "verify succeeds without configuration" do
    service = InternetArchiveService.new
    result = service.verify({})

    assert_equal true, result[:success]
  end

  test "save_url returns error when url is blank" do
    service = InternetArchiveService.new
    result = service.save_url(nil)

    assert_equal({ error: "URL is required" }, result)
  end

  test "post returns nil when crosspost is disabled" do
    Crosspost.internet_archive.update!(enabled: false)
    service = InternetArchiveService.new

    assert_nil service.post(create_published_article)
  end
end
