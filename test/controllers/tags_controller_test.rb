require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tag = tags(:ruby)
    @article = articles(:published_article)
    @article.tags << @tag unless @article.tags.include?(@tag)
  end

  test "index and show tag with rss" do
    get tags_path
    assert_response :success

    get tag_path(@tag.slug)
    assert_response :success
    assert_includes response.body, @tag.name

    get tag_path(@tag.slug, format: :rss)
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
  end
end
