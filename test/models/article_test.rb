require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  def setup
    @article = Article.new(
      title: "Test Article",
      description: "Test description",
      status: :draft
    )
  end

  test "should be valid with valid attributes" do
    assert @article.valid?
  end

  test "should generate slug from title" do
    @article.title = "My Test Article"
    @article.valid?
    assert_equal "my-test-article", @article.slug
  end

  test "should generate unique slug when duplicate exists" do
    Article.create!(title: "Test Article", status: :draft)
    @article.title = "Test Article"
    @article.valid?
    assert_not_equal "test-article", @article.slug
    assert @article.slug.start_with?("test-article")
  end

  test "should remove dots from slug" do
    @article.title = "Article v1.0"
    @article.valid?
    assert_not @article.slug.include?(".")
  end

  test "should require slug to be unique" do
    existing_article = articles(:published_article)
    @article.slug = existing_article.slug
    assert_not @article.valid?
    assert_includes @article.errors[:slug], "has already been taken"
  end

  test "should require scheduled_at when status is schedule" do
    @article.status = :schedule
    @article.scheduled_at = nil
    assert_not @article.valid?
    assert_includes @article.errors[:scheduled_at], "can't be blank"
  end

  test "should not require scheduled_at when status is not schedule" do
    @article.status = :draft
    @article.scheduled_at = nil
    assert @article.valid?
  end

  test "published scope should return only published articles" do
    published = articles(:published_article)
    draft = articles(:draft_article)

    published_articles = Article.published
    assert_includes published_articles, published
    assert_not_includes published_articles, draft
  end

  test "by_status scope should filter by status" do
    draft_articles = Article.by_status(:draft)
    assert_includes draft_articles, articles(:draft_article)
    assert_not_includes draft_articles, articles(:published_article)
  end

  test "publishable scope should return scheduled articles ready to publish" do
    scheduled = articles(:scheduled_article)
    scheduled.update!(scheduled_at: 1.hour.ago)

    publishable = Article.publishable
    assert_includes publishable, scheduled
  end

  test "publishable scope should not return future scheduled articles" do
    scheduled = articles(:scheduled_article)
    scheduled.update!(scheduled_at: 1.hour.from_now)

    publishable = Article.publishable
    assert_not_includes publishable, scheduled
  end

  test "to_param should return slug" do
    @article.slug = "test-slug"
    assert_equal "test-slug", @article.to_param
  end

  test "publish_scheduled should update status to publish" do
    article = articles(:scheduled_article)
    article.update!(scheduled_at: 1.hour.ago)

    article.publish_scheduled
    assert article.publish?
    assert_nil article.scheduled_at
  end

  test "publish_scheduled should not update if not ready" do
    article = articles(:scheduled_article)
    article.update!(scheduled_at: 1.hour.from_now)
    original_status = article.status

    article.publish_scheduled
    assert_equal original_status, article.status
  end

  test "tag_list should return comma-separated tag names" do
    article = articles(:published_article)
    tag1 = tags(:ruby)
    tag2 = tags(:rails)
    article.tags << [ tag1, tag2 ]

    assert_equal "Ruby, Rails", article.tag_list
  end

  test "tag_list= should create tags from comma-separated string" do
    @article.save!
    @article.tag_list = "ruby, rails, javascript"

    assert_equal 3, @article.tags.count
    assert @article.tags.pluck(:name).include?("ruby")
    assert @article.tags.pluck(:name).include?("rails")
    assert @article.tags.pluck(:name).include?("javascript")
  end

  test "tag_list= should reuse existing tags" do
    existing_tag = tags(:ruby)
    @article.save!
    @article.tag_list = "ruby, new-tag"

    assert_equal 2, @article.tags.count
    assert_includes @article.tags, existing_tag
  end

  test "search_content should find articles by title" do
    article = articles(:published_article)
    results = Article.search_content("Published")
    assert_includes results, article
  end

  test "search_content should find articles by slug" do
    article = articles(:published_article)
    results = Article.search_content("published-article")
    assert_includes results, article
  end

  test "search_content should return all when query is blank" do
    results = Article.search_content("")
    assert_equal Article.count, results.count
  end

  test "should have many comments" do
    article = articles(:published_article)
    assert_respond_to article, :comments
  end

  test "should have many tags through article_tags" do
    article = articles(:published_article)
    assert_respond_to article, :tags
  end

  test "should have many social_media_posts" do
    article = articles(:published_article)
    assert_respond_to article, :social_media_posts
  end

  test "should destroy associated comments when destroyed" do
    article = articles(:published_article)
    comment = comments(:approved_comment)
    article.comments << comment

    assert_difference "Comment.count", -1 do
      article.destroy
    end
  end

  test "should destroy associated article_tags when destroyed" do
    article = articles(:published_article)
    tag = tags(:ruby)
    article.tags << tag

    assert_difference "ArticleTag.count", -1 do
      article.destroy
    end
  end
end

