require "test_helper"

class Admin::ArticlesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:admin)
    @article = articles(:published_article)
    @draft_article = articles(:draft_article)
    sign_in(@user)
  end

  test "should get index" do
    get admin_articles_path
    assert_response :success
  end

  test "should get show" do
    get admin_article_path(@article.slug)
    assert_response :success
  end

  test "should get new" do
    get new_admin_article_path
    assert_response :success
  end

  test "should get edit" do
    get edit_admin_article_path(@article.slug)
    assert_response :success
  end

  test "should create article" do
    assert_difference "Article.count", 1 do
      post admin_articles_path, params: {
        article: {
          title: "New Admin Article",
          description: "Description",
          status: "draft",
          content: "Content"
        }
      }
    end
    
    assert_redirected_to admin_articles_path
  end

  test "should create article and add another" do
    assert_difference "Article.count", 1 do
      post admin_articles_path, params: {
        article: {
          title: "New Article",
          description: "Description",
          status: "draft",
          content: "Content"
        },
        create_and_add_another: "1"
      }
    end
    
    assert_redirected_to new_admin_article_path
  end

  test "should update article" do
    patch admin_article_path(@article.slug), params: {
      article: {
        title: "Updated Title"
      }
    }
    
    assert_redirected_to admin_articles_path
    @article.reload
    assert_equal "Updated Title", @article.title
  end

  test "should get drafts" do
    get drafts_admin_articles_path
    assert_response :success
  end

  test "should get scheduled" do
    get scheduled_admin_articles_path
    assert_response :success
  end

  test "should publish article" do
    patch publish_admin_article_path(@draft_article.slug)
    
    assert_redirected_to admin_articles_path
    @draft_article.reload
    assert @draft_article.publish?
  end

  test "should unpublish article" do
    patch unpublish_admin_article_path(@article.slug)
    
    assert_redirected_to admin_articles_path
    @article.reload
    assert @article.draft?
  end

  test "should batch add tags" do
    tag = tags(:ruby)
    
    post batch_add_tags_admin_articles_path, params: {
      ids: [@article.slug],
      tag_names: "ruby, rails"
    }
    
    assert_redirected_to admin_articles_path
    @article.reload
    assert @article.tags.pluck(:name).include?("ruby")
  end

  test "should not batch add tags without ids" do
    post batch_add_tags_admin_articles_path, params: {
      ids: [],
      tag_names: "ruby"
    }
    
    assert_redirected_to admin_articles_path
  end

  test "should not batch add tags without tag names" do
    post batch_add_tags_admin_articles_path, params: {
      ids: [@article.slug],
      tag_names: ""
    }
    
    assert_redirected_to admin_articles_path
  end

  test "should batch destroy articles" do
    post batch_destroy_admin_articles_path, params: {
      ids: [@article.slug]
    }
    
    assert_redirected_to admin_articles_path
    @article.reload
    assert_equal "trash", @article.status
  end

  test "should permanently delete trashed articles in batch" do
    trash_article = articles(:trash_article)
    
    assert_difference "Article.count", -1 do
      post batch_destroy_admin_articles_path, params: {
        ids: [trash_article.slug]
      }
    end
  end

  test "should fetch comments" do
    # This test would require mocking the social media services
    # For now, we'll test the basic structure
    skip "Requires social media service mocking"
  end
end
