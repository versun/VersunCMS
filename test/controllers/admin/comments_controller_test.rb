require "test_helper"

class Admin::CommentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:admin)
    @pending_comment = comments(:pending_comment)
    @approved_comment = comments(:approved_comment)
    sign_in(@user)
  end

  test "admin comment workflows" do
    get admin_comments_path
    assert_response :success

    get admin_comments_path, params: { status: "approved" }
    assert_response :success

    get admin_comment_path(@pending_comment)
    assert_response :not_acceptable

    get edit_admin_comment_path(@pending_comment)
    assert_response :success

    patch admin_comment_path(@pending_comment), params: { comment: { content: "Updated content" } }
    assert_redirected_to admin_comments_path
    assert_equal "Updated content", @pending_comment.reload.content

    patch admin_comment_path(@pending_comment), params: { comment: { author_name: "" } }
    assert_response :unprocessable_entity

    patch approve_admin_comment_path(@pending_comment)
    assert_redirected_to admin_comments_path
    assert @pending_comment.reload.approved?

    patch reject_admin_comment_path(@approved_comment)
    assert_redirected_to admin_comments_path
    assert @approved_comment.reload.rejected?

    batch_comment = Comment.create!(
      commentable: articles(:published_article),
      author_name: "Batch User",
      content: "Batch content",
      status: :pending
    )

    post batch_approve_admin_comments_path, params: { ids: [ batch_comment.id ] }
    assert_redirected_to admin_comments_path
    assert batch_comment.reload.approved?

    post batch_reject_admin_comments_path, params: { ids: [ batch_comment.id ] }
    assert_redirected_to admin_comments_path
    assert batch_comment.reload.rejected?

    assert_difference "Comment.count", -1 do
      post batch_destroy_admin_comments_path, params: { ids: [ batch_comment.id ] }
    end
  end
end
