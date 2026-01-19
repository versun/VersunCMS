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

  test "tag rss uses content fallback title when missing" do
    tag = create_tag(name: "rss-fallback")
    article = create_published_article(
      title: nil,
      html_content: "<p>12345678901234567890REST</p>"
    )
    article.tags << tag

    get tag_path(tag.slug, format: :rss)
    assert_response :success
    assert_includes response.body, "<title>12345678901234567890</title>"
  end

  test "tag rss escapes fallback title content" do
    tag = create_tag(name: "rss-escape")
    article = create_published_article(
      title: nil,
      html_content: "<p>Fish & Chips < 5 > 3</p>"
    )
    article.tags << tag

    get tag_path(tag.slug, format: :rss)
    assert_response :success
    assert_includes response.body, "<title>Fish &amp; Chips &lt; 5 &gt; 3</title>"
  end
end
