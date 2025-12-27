require "test_helper"

class ContentBuilderTest < ActiveSupport::TestCase
  class DummyBuilder
    include ContentBuilder
  end

  setup do
    @builder = DummyBuilder.new
    @source_url = "https://example.com/source"
  end

  test "without truncation: no read more and reference url is last (with title)" do
    article = create_published_article(
      title: "Hello",
      html_content: "<p>Short content</p>",
      description: nil,
      source_url: @source_url
    )

    post = @builder.build_content(article: article, max_length: 300)

    assert_not_includes post, "Read more:"
    assert_includes post, @source_url
    assert post.end_with?(@source_url)
  end

  test "with truncation: has read more and reference url is last (with title)" do
    article = create_published_article(
      title: "Hello",
      html_content: "<p>#{'a' * 200}</p>",
      description: nil,
      source_url: @source_url
    )

    post = @builder.build_content(article: article, max_length: 60)

    assert_includes post, "Read more:"
    assert_includes post, @source_url
    assert_operator post.index("Read more:"), :<, post.index(@source_url)
    assert post.end_with?(@source_url)
  end

  test "without truncation: no read more and reference url is last (no title)" do
    article = create_published_article(
      title: nil,
      html_content: "<p>Short content</p>",
      description: nil,
      source_url: @source_url
    )

    post = @builder.build_content(article: article, max_length: 300)

    assert_not_includes post, "Read more:"
    assert_includes post, @source_url
    assert post.end_with?(@source_url)
  end

  test "with truncation: has read more and reference url is last (no title)" do
    article = create_published_article(
      title: nil,
      html_content: "<p>#{'a' * 200}</p>",
      description: nil,
      source_url: @source_url
    )

    post = @builder.build_content(article: article, max_length: 60)

    assert_includes post, "Read more:"
    assert_includes post, @source_url
    assert_operator post.index("Read more:"), :<, post.index(@source_url)
    assert post.end_with?(@source_url)
  end
end
