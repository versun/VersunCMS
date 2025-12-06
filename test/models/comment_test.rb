require "test_helper"

class CommentTest < ActiveSupport::TestCase
  def setup
    @article = articles(:published_article)
    @comment = Comment.new(
      article: @article,
      author_name: "Test User",
      content: "Test comment content"
    )
  end

  test "should be valid with valid attributes" do
    assert @comment.valid?
  end

  test "should require author_name" do
    @comment.author_name = nil
    assert_not @comment.valid?
    assert_includes @comment.errors[:author_name], "can't be blank"
  end

  test "should require content" do
    @comment.content = nil
    assert_not @comment.valid?
    assert_includes @comment.errors[:content], "can't be blank"
  end

  test "should require article_id" do
    @comment.article_id = nil
    assert_not @comment.valid?
    assert_includes @comment.errors[:article_id], "can't be blank"
  end

  test "should require platform for external comments" do
    @comment.platform = "mastodon"
    @comment.external_id = "123"
    @comment.valid?
    # Platform is required if external_comment?
    assert @comment.valid?
  end

  test "should require external_id for external comments" do
    @comment.platform = "mastodon"
    @comment.external_id = nil
    assert_not @comment.valid?
    assert_includes @comment.errors[:external_id], "can't be blank"
  end

  test "should require unique external_id per article and platform" do
    existing_comment = comments(:mastodon_comment)
    @comment.platform = existing_comment.platform
    @comment.external_id = existing_comment.external_id
    @comment.article = existing_comment.article
    
    assert_not @comment.valid?
    assert_includes @comment.errors[:external_id], "has already been taken"
  end

  test "should validate author_url format" do
    @comment.author_url = "not-a-url"
    assert_not @comment.valid?
  end

  test "should accept valid URLs" do
    @comment.author_url = "https://example.com"
    assert @comment.valid?
  end

  test "should allow blank author_url" do
    @comment.author_url = ""
    assert @comment.valid?
  end

  test "should validate parent belongs to same article" do
    article1 = create_published_article
    article2 = create_published_article
    
    parent_comment = Comment.create!(
      article: article1,
      author_name: "Parent",
      content: "Parent comment"
    )
    
    @comment.article = article2
    @comment.parent_id = parent_comment.id
    
    assert_not @comment.valid?
    assert_includes @comment.errors[:parent_id], "must belong to the same article"
  end

  test "should allow parent from same article" do
    parent_comment = Comment.create!(
      article: @article,
      author_name: "Parent",
      content: "Parent comment"
    )
    
    @comment.parent_id = parent_comment.id
    assert @comment.valid?
  end

  test "local scope should return comments without platform" do
    local_comment = comments(:approved_comment)
    external_comment = comments(:mastodon_comment)
    
    local_comments = Comment.local
    assert_includes local_comments, local_comment
    assert_not_includes local_comments, external_comment
  end

  test "mastodon scope should return only mastodon comments" do
    mastodon_comment = comments(:mastodon_comment)
    local_comment = comments(:approved_comment)
    
    mastodon_comments = Comment.mastodon
    assert_includes mastodon_comments, mastodon_comment
    assert_not_includes mastodon_comments, local_comment
  end

  test "top_level scope should return comments without parent" do
    parent_comment = Comment.create!(
      article: @article,
      author_name: "Parent",
      content: "Parent comment"
    )
    
    reply_comment = Comment.create!(
      article: @article,
      author_name: "Reply",
      content: "Reply comment",
      parent: parent_comment
    )
    
    top_level = Comment.top_level
    assert_includes top_level, parent_comment
    assert_not_includes top_level, reply_comment
  end

  test "should have replies" do
    parent_comment = Comment.create!(
      article: @article,
      author_name: "Parent",
      content: "Parent comment"
    )
    
    reply = Comment.create!(
      article: @article,
      author_name: "Reply",
      content: "Reply comment",
      parent: parent_comment
    )
    
    assert_includes parent_comment.replies, reply
  end

  test "should default to pending status" do
    comment = Comment.new(
      article: @article,
      author_name: "Test",
      content: "Test"
    )
    assert_equal "pending", comment.status
  end

  test "should belong to article" do
    assert_respond_to @comment, :article
  end

  test "should belong to parent comment" do
    assert_respond_to @comment, :parent
  end

  test "should destroy replies when destroyed" do
    parent_comment = Comment.create!(
      article: @article,
      author_name: "Parent",
      content: "Parent comment"
    )
    
    reply = Comment.create!(
      article: @article,
      author_name: "Reply",
      content: "Reply comment",
      parent: parent_comment
    )
    
    assert_difference "Comment.count", -2 do
      parent_comment.destroy
    end
  end
end
