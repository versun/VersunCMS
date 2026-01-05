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

  test "show page renders source reference link inside the quote block" do
    article = create_published_article(
      title: "Article With Source Reference",
      description: "",
      content: "<p>Body</p>",
      source_content: "Quoted source text",
      source_url: "https://example.com/original"
    )

    visit article_path(article)

    assert_selector ".source-reference__quote .source-reference__links"
    assert_selector ".source-reference__quote a", text: "Original"
    assert_no_selector ".source-reference__quote a", text: "Archive"
  end

  test "home page shows description, falls back to full content when description blank" do
    article_with_description = create_published_article(
      title: "Article With Description",
      description: "Only the description should be shown",
      content: "<p>CONTENT SHOULD NOT APPEAR</p>"
    )
    article_without_description = create_published_article(
      title: "Article Without Description",
      description: "",
      content: "<p>Fallback content should appear</p>"
    )

    visit root_path

    assert_text article_with_description.title
    assert_text "Only the description should be shown"
    assert_no_text "CONTENT SHOULD NOT APPEAR"

    assert_text article_without_description.title
    assert_text "Fallback content should appear"
  end

  test "space key works on nested interactive controls inside a clickable card" do
    skip "This test requires JavaScript support (Selenium)" unless self.class.use_selenium?

    details_id = "nested-details-#{Time.current.to_i}-#{rand(10000)}"
    summary_id = "nested-summary-#{Time.current.to_i}-#{rand(10000)}"

    article = create_published_article(
      title: "Article With Details Toggle",
      description: "",
      content: %(<details id="#{details_id}"><summary id="#{summary_id}">Toggle details</summary><div>Hidden content</div></details>)
    )

    visit root_path
    assert_text article.title
    assert_no_selector "##{details_id}[open]"

    page.execute_script("document.getElementById(#{summary_id.to_json}).focus()")
    page.send_keys(:space)

    assert_selector "##{details_id}[open]"
  end

  test "viewing a published article directly" do
    article = create_published_article(title: "Direct View Article", content: "Direct view content")

    visit article_path(article)

    assert_text article.title
    assert_text "share"
  end

  test "show page hides unsupported social platforms" do
    article = create_published_article(title: "Unsupported Platform Article", content: "Body")
    article.social_media_posts.create!(platform: "mastodon", url: "https://mastodon.social/@test/1")
    article.social_media_posts.create!(platform: "internet_archive", url: "https://web.archive.org/web/123/http://example.com")

    visit article_path(article)

    assert_selector "a[title='Mastodon']"
    assert_no_selector "a[title='Internet Archive']"
    assert_no_text "Internet Archive"
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
