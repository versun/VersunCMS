require "application_system_test_case"

class ArticlesTest < ApplicationSystemTestCase
  def setup
    @article = articles(:published_article)
    @user = users(:admin)
  end

  test "visiting the index" do
    visit articles_path

    assert_selector "h1", text: "Articles"
    assert_text @article.title
  end

  test "searching articles" do
    visit articles_path

    fill_in "Search", with: "Published"
    click_button "Search"

    assert_text @article.title
  end

  test "viewing an article" do
    visit article_path(@article.slug)

    assert_text @article.title
    assert_text @article.description
  end

  test "creating an article when authenticated" do
    sign_in(@user)
    visit new_admin_article_path

    fill_in "Title", with: "New System Test Article"
    fill_in "Description", with: "System test description"
    select "draft", from: "Status"

    click_button "Create Article"

    assert_text "Article was successfully created"
    assert_text "New System Test Article"
  end

  test "updating an article when authenticated" do
    sign_in(@user)
    visit edit_admin_article_path(@article.slug)

    fill_in "Title", with: "Updated System Test Title"
    click_button "Update Article"

    assert_text "Article was successfully updated"
    assert_text "Updated System Test Title"
  end

  test "publishing an article" do
    sign_in(@user)
    draft = articles(:draft_article)

    visit admin_articles_path
    click_link "Publish", href: publish_admin_article_path(draft.slug)

    assert_text "Article was successfully published"
    draft.reload
    assert draft.publish?
  end

  test "moving article to trash" do
    sign_in(@user)
    visit admin_articles_path

    accept_confirm do
      click_link "Delete", href: admin_article_path(@article.slug)
    end

    assert_text "Article was successfully moved to trash"
    @article.reload
    assert_equal "trash", @article.status
  end
end

