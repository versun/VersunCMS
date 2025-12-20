require "application_system_test_case"

class ArticlesTest < ApplicationSystemTestCase
  test "opening a published article from the home page" do
    article = create_published_article(title: "System Test Article", content: "Hello from system test")

    visit root_path
    assert_text article.title

    # Click the article link - use first: true in case of multiple matching elements
    click_link article.title, match: :first

    # Wait for navigation and check we're on the article page
    # The path should be the article slug
    assert_text article.title
    assert_text "share"
  end

  test "viewing a published article directly" do
    article = create_published_article(title: "Direct View Article", content: "Direct view content")

    visit article_path(article)

    assert_text article.title
    assert_text "share"
  end

  test "browsing articles by tag" do
    tag = create_tag(name: "SystemTest")
    article = create_published_article(title: "Tagged Article", content: "Tagged content")
    article.tags << tag

    visit tags_path
    assert_text "All Tags"
    assert_text tag.name

    click_link tag.name, match: :first
    assert_text %Q(Articles tagged with "#{tag.name}")
    assert_text article.title
    assert_text "RSS"
  end
end
