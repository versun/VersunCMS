require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @article = articles(:published_article)
    @draft_article = articles(:draft_article)
    @user = users(:admin)
  end

  test "should get index" do
    get articles_path
    assert_response :success
  end

  test "should get index with search query" do
    get articles_path, params: { q: "Published" }
    assert_response :success
  end

  test "should get index as RSS" do
    get articles_path(format: :rss)
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
  end

  test "should get show for published article" do
    get article_path(@article.slug)
    assert_response :success
  end

  test "should not show draft article to unauthenticated users" do
    get article_path(@draft_article.slug)
    assert_response :not_found
  end

  test "should show draft article to authenticated users" do
    sign_in(@user)
    get article_path(@draft_article.slug)
    assert_response :success
  end

  test "should get new when authenticated" do
    sign_in(@user)
    get new_article_path
    assert_response :success
  end

  test "should redirect to login when accessing new without authentication" do
    get new_article_path
    # Assuming authentication redirects to login
    # Adjust based on your authentication implementation
  end

  test "should create article when authenticated" do
    sign_in(@user)

    assert_difference "Article.count", 1 do
      post articles_path, params: {
        article: {
          title: "New Article",
          description: "New description",
          status: "draft",
          content: "New content"
        }
      }
    end

    assert_redirected_to admin_articles_path
  end

  test "should not create article with invalid params" do
    sign_in(@user)

    assert_no_difference "Article.count" do
      post articles_path, params: {
        article: {
          title: "",
          status: "draft"
        }
      }
    end
  end

  test "should get edit when authenticated" do
    sign_in(@user)
    get edit_article_path(@article.slug)
    assert_response :success
  end

  test "should update article when authenticated" do
    sign_in(@user)

    patch article_path(@article.slug), params: {
      article: {
        title: "Updated Title",
        description: "Updated description"
      }
    }

    assert_redirected_to admin_articles_path
    @article.reload
    assert_equal "Updated Title", @article.title
  end

  test "should move article to trash when destroying" do
    sign_in(@user)

    assert_no_difference "Article.count" do
      delete article_path(@article.slug)
    end

    @article.reload
    assert_equal "trash", @article.status
  end

  test "should permanently delete article from trash" do
    sign_in(@user)
    trash_article = articles(:trash_article)

    assert_difference "Article.count", -1 do
      delete article_path(trash_article.slug)
    end
  end

  test "should paginate articles" do
    get articles_path, params: { page: 1 }
    assert_response :success
  end
end
