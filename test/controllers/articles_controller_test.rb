
require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get articles_url
    assert_response :success
  end

  test "should get show for published article" do
    article = articles(:one)
    get article_url(article.slug)
    assert_response :success
  end

  test "should get rss feed" do
    get articles_url(format: :rss)
    assert_response :success
    assert_equal "application/rss+xml", @response.media_type
  end
end
