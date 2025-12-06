require "test_helper"

class PageTest < ActiveSupport::TestCase
  def setup
    @page = Page.new(
      title: "Test Page",
      slug: "test-page",
      status: :draft
    )
  end

  test "should be valid with valid attributes" do
    assert @page.valid?
  end

  test "should require title" do
    @page.title = nil
    assert_not @page.valid?
  end

  test "should require unique slug" do
    existing_page = Page.create!(
      title: "Existing",
      slug: "existing-page",
      status: :draft
    )
    @page.slug = existing_page.slug
    assert_not @page.valid?
  end

  test "should have status enum" do
    assert_respond_to @page, :status
  end

  test "should have published scope" do
    published_page = Page.create!(
      title: "Published Page",
      slug: "published-page",
      status: :publish
    )

    draft_page = Page.create!(
      title: "Draft Page",
      slug: "draft-page",
      status: :draft
    )

    published = Page.published
    assert_includes published, published_page
    assert_not_includes published, draft_page
  end

  test "to_param should return slug" do
    @page.slug = "test-slug"
    assert_equal "test-slug", @page.to_param
  end

  test "redirect? should return true when redirect_url is present" do
    @page.redirect_url = "https://example.com"
    assert @page.redirect?
  end

  test "redirect? should return false when redirect_url is blank" do
    assert_not @page.redirect?
  end

  test "should validate redirect_url format" do
    @page.redirect_url = "not-a-url"
    assert_not @page.valid?
  end

  test "should allow blank redirect_url" do
    @page.redirect_url = ""
    assert @page.valid?
  end
end
