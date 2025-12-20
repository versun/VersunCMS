require "application_system_test_case"

class AdminArticlesTest < ApplicationSystemTestCase
  def setup
    @user = users(:admin)
  end

  test "publishing and trashing an article" do
    article = create_draft_article(title: "Admin Flow Draft", content: "Draft body")

    sign_in(@user)

    visit edit_admin_article_path(article)
    select "publish", from: "status_select"
    click_button "Save"

    assert_text "Article was successfully updated."
    article.reload
    assert article.publish?

    page.driver.submit :delete, admin_article_path(article), {}
    assert_text "Article was successfully moved to trash."

    article.reload
    assert article.trash?
  end
end

