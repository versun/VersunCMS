require "test_helper"

class ListmonkTest < ActiveSupport::TestCase
  test "campaign_body includes source reference before content when article has source" do
    listmonk = Listmonk.new
    article = articles(:source_article)

    body = listmonk.send(:campaign_body, article)

    assert_includes body, "Example Author"
    assert_includes body, "Example source quote."
    assert_includes body, "https://example.com/source"
    assert_includes body, "<p>Source article content</p>"
    assert body.index("Example source quote.") < body.index("Source article content")
  end

  test "campaign_body does not add reference when article has no source" do
    listmonk = Listmonk.new
    article = articles(:published_article)

    body = listmonk.send(:campaign_body, article)

    refute_includes body, "source-reference__quote"
    assert_includes body, "<p>Published article content</p>"
  end
end
