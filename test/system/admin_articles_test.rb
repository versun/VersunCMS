require "application_system_test_case"

class AdminArticlesTest < ApplicationSystemTestCase
  def setup
    @user = users(:admin)
  end

  test "publishing an article" do
    article = create_draft_article(title: "Admin Flow Draft", content: "Draft body")

    sign_in(@user)

    visit edit_admin_article_path(article)
    select "publish", from: "status_select"
    click_button "Save"

    assert_text "Article was successfully updated."
    article.reload
    assert article.publish?
  end

  test "trashing an article" do
    skip "This test requires JavaScript support (Selenium)" unless self.class.use_selenium?

    article = create_draft_article(title: "Article to Trash", content: "Draft body")

    sign_in(@user)

    # Navigate to admin articles list and delete the article
    visit admin_articles_path
    # Find the article row and click delete (using accept_confirm to handle JS confirmation)
    accept_confirm do
      find("tr", text: article.title).click_link("Delete")
    end

    assert_text "Article was successfully moved to trash."

    article.reload
    assert article.trash?
  end
end
