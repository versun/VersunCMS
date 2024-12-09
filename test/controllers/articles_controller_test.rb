require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  fixtures :articles, :users
  setup do
    @published_post = articles(:published_post)
    @draft_post = articles(:draft_post)
    @published_page = articles(:published_page)
    @scheduled_post = articles(:scheduled_post)
  end

  test "should get index and only show published posts" do
    get articles_url
    assert_response :success
    assert_select "article", count: 1  # Only published_post should be visible
  end

  test "should get index with RSS feed" do
    get articles_url(format: :rss)
    assert_response :success
    assert_select "item", count: 1  # Only published_post should be in RSS
  end

  test "should get index with search" do
    get articles_url(q: "Published")
    assert_response :success
    assert_select "article", count: 1  # Should find published_post
  end

  test "should show published post" do
    get article_url(@published_post)
    assert_response :success
  end

  test "should show published page" do
    get article_url(@published_page)
    assert_response :success
  end

  test "should not show draft post" do
    get article_url(@draft_post)
    assert_redirected_to root_path
    assert_equal "Article Not found.", flash[:notice]
  end

  test "should not show scheduled post" do
    get article_url(@scheduled_post)
    assert_redirected_to root_path
    assert_equal "Article Not found.", flash[:notice]
  end

  # Authenticated tests
  test "should get new article form when authenticated" do
    sign_in_as(users(:admin))
    get new_article_url
    assert_response :success
  end

  test "should get new page form when authenticated" do
    sign_in_as(users(:admin))
    get new_article_url(is_page: true)
    assert_response :success
  end

  test "should create post when authenticated" do
    sign_in_as(users(:admin))
    assert_difference("Article.count") do
      post articles_url, params: {
        article: {
          title: "New Test Post",
          content: "Test Content",
          status: "publish"
        }
      }
    end

    article = Article.last
    assert_equal "new-test-post", article.slug
    assert_equal "publish", article.status
    assert_not article.is_page
    assert_redirected_to admin_posts_path
    assert_equal "Created successfully.", flash[:notice]
  end

  test "should create scheduled post when authenticated" do
    sign_in_as(users(:admin))
    scheduled_time = 1.day.from_now
    assert_difference("Article.count") do
      post articles_url, params: {
        article: {
          title: "Scheduled Post",
          content: "Test Content",
          status: "schedule",
          scheduled_at: scheduled_time
        }
      }
    end

    article = Article.last
    assert_equal "schedule", article.status
    assert_equal scheduled_time.to_i, article.scheduled_at.to_i
    assert_redirected_to admin_posts_path
  end

  test "should create page when authenticated" do
    sign_in_as(users(:admin))
    assert_difference("Article.count") do
      post articles_url, params: {
        article: {
          title: "New Page",
          content: "Page Content",
          is_page: true,
          status: "publish",
          page_order: 2
        }
      }
    end

    article = Article.last
    assert article.is_page
    assert_equal 2, article.page_order
    assert_redirected_to admin_pages_path
  end

  test "should update article when authenticated" do
    sign_in_as(users(:admin))
    patch article_url(@published_post), params: {
      article: {
        title: "Updated Title",
        content: "Updated Content",
        status: "draft"
      }
    }

    @published_post.reload
    assert_equal "Updated Title", @published_post.title
    assert_equal "draft", @published_post.status
    assert_redirected_to admin_posts_path
  end

  test "should update page order when authenticated" do
    sign_in_as(users(:admin))
    patch article_url(@published_page), params: {
      article: {
        page_order: 3
      }
    }

    @published_page.reload
    assert_equal 3, @published_page.page_order
    assert_redirected_to admin_pages_path
  end

  test "should move to trash when authenticated" do
    sign_in_as(users(:admin))
    delete article_url(@published_post)
    
    @published_post.reload
    assert_equal "trash", @published_post.status
    assert_redirected_to admin_posts_path
    assert_equal "Article was successfully moved to trash.", flash[:notice]
  end

  test "should permanently delete from trash when authenticated" do
    sign_in_as(users(:admin))
    @published_post.update!(status: "trash")
    
    assert_difference("Article.count", -1) do
      delete article_url(@published_post)
    end

    assert_redirected_to admin_posts_path
    assert_equal "Article was successfully destroyed.", flash[:notice]
  end

  test "should handle invalid article creation when authenticated" do
    sign_in_as(users(:admin))
    assert_no_difference("Article.count") do
      post articles_url, params: {
        article: {
          title: "",  # Title is required
          status: "publish"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should handle invalid scheduled post when authenticated" do
    sign_in_as(users(:admin))
    assert_no_difference("Article.count") do
      post articles_url, params: {
        article: {
          title: "Test",
          status: "schedule"
          # Missing scheduled_at, which is required for scheduled posts
        }
      }
    end

    assert_response :unprocessable_entity
  end

  private
    def sign_in_as(user)
      session = user.sessions.create!(
        user_agent: "Rails Testing",
        ip_address: "127.0.0.1"
      )
      cookies[:session_id] = session.id
      session
    end
end
