class Admin::CommentsController < AdminController
  before_action :set_comment, only: [ :show, :edit, :update, :destroy, :approve, :reject, :reply ]

  def index
    @comments = Comment.includes(:commentable, :article, parent: :commentable)

    # Filter by status
    # Filter by status
    if params[:status].present? && Comment.statuses.key?(params[:status])
      @comments = @comments.where(status: params[:status])
    end

    @comments = @comments.reorder(Arel.sql("COALESCE(published_at, created_at) DESC"))
                         .paginate(page: params[:page], per_page: 30)
  end

  def show
  end

  def edit
  end

  def update
    if @comment.update(comment_params)
      ActivityLog.create!(
        action: "updated",
        target: "comment",
        level: :info,
        description: "更新评论: #{@comment.commentable_type}##{@comment.commentable_id}"
      )
      redirect_to admin_comments_path, notice: "Comment updated successfully."
    else
      ActivityLog.create!(
        action: "failed",
        target: "comment",
        level: :error,
        description: "更新评论失败: #{@comment.errors.full_messages.join(', ')}"
      )
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    commentable_info = "#{@comment.commentable_type}##{@comment.commentable_id}"
    @comment.destroy
    ActivityLog.create!(
      action: "deleted",
      target: "comment",
      level: :info,
      description: "删除评论: #{commentable_info}"
    )
    redirect_to admin_comments_path, notice: "Comment deleted successfully."
  end

  def approve
    if @comment.approved!
      ActivityLog.create!(
        action: "approved",
        target: "comment",
        level: :info,
        description: "批准评论: #{@comment.commentable_type}##{@comment.commentable_id}"
      )
      redirect_to admin_comments_path, notice: "Comment approved successfully."
    else
      ActivityLog.create!(
        action: "failed",
        target: "comment",
        level: :error,
        description: "批准评论失败: #{@comment.commentable_type}##{@comment.commentable_id}"
      )
      redirect_to admin_comments_path, alert: "Failed to approve comment."
    end
  end

  def reject
    if @comment.rejected!
      ActivityLog.create!(
        action: "rejected",
        target: "comment",
        level: :info,
        description: "拒绝评论: #{@comment.commentable_type}##{@comment.commentable_id}"
      )
      redirect_to admin_comments_path, notice: "Comment rejected."
    else
      ActivityLog.create!(
        action: "failed",
        target: "comment",
        level: :error,
        description: "拒绝评论失败: #{@comment.commentable_type}##{@comment.commentable_id}"
      )
      redirect_to admin_comments_path, alert: "Failed to reject comment."
    end
  end

  def reply
    if @comment.platform.present?
      redirect_to admin_comments_path, alert: "Cannot reply to external comments."
      return
    end

    if @comment.rejected?
      redirect_to admin_comments_path, alert: "Cannot reply to rejected comments."
      return
    end

    commentable = @comment.commentable || @comment.display_commentable
    unless commentable
      redirect_to admin_comments_path, alert: "Commentable not found."
      return
    end

    author_name = reply_author_name
    if author_name.blank?
      redirect_to admin_comments_path, alert: "Please set the site author name in Settings before replying."
      return
    end

    reply_comment = commentable.comments.build(
      parent: @comment,
      author_name: author_name,
      author_url: reply_author_url,
      content: reply_params[:content],
      status: :approved,
      published_at: Time.current
    )

    if reply_comment.save
      ActivityLog.create!(
        action: "replied",
        target: "comment",
        level: :info,
        description: "回复评论: #{commentable.class.name}##{commentable.id} (#{author_name})"
      )
      redirect_to admin_comments_path, notice: "Reply posted successfully."
    else
      ActivityLog.create!(
        action: "failed",
        target: "comment",
        level: :error,
        description: "回复评论失败: #{reply_comment.errors.full_messages.join(', ')}"
      )
      redirect_to admin_comments_path, alert: "Failed to reply: #{reply_comment.errors.full_messages.join(', ')}"
    end
  end

  def batch_destroy
    ids = params[:ids] || []
    count = 0

    ids.each do |id|
      comment = Comment.find_by(id: id)
      if comment
        comment.destroy
        count += 1
      end
    end

    ActivityLog.create!(
      action: "deleted",
      target: "comment",
      level: :info,
      description: "批量删除评论: #{count}条"
    )
    redirect_to admin_comments_path, notice: "Successfully deleted #{count} comment(s)."
  rescue => e
    ActivityLog.create!(
      action: "failed",
      target: "comment",
      level: :error,
      description: "批量删除评论失败: #{e.message}"
    )
    redirect_to admin_comments_path, alert: "Error deleting comments: #{e.message}"
  end

  def batch_approve
    ids = params[:ids] || []
    count = 0

    ids.each do |id|
      comment = Comment.find_by(id: id)
      if comment && comment.approved!
        count += 1
      end
    end

    ActivityLog.create!(
      action: "approved",
      target: "comment",
      level: :info,
      description: "批量批准评论: #{count}条"
    )
    redirect_to admin_comments_path, notice: "Successfully approved #{count} comment(s)."
  rescue => e
    ActivityLog.create!(
      action: "failed",
      target: "comment",
      level: :error,
      description: "批量批准评论失败: #{e.message}"
    )
    redirect_to admin_comments_path, alert: "Error approving comments: #{e.message}"
  end

  def batch_reject
    ids = params[:ids] || []
    count = 0

    ids.each do |id|
      comment = Comment.find_by(id: id)
      if comment && comment.rejected!
        count += 1
      end
    end

    ActivityLog.create!(
      action: "rejected",
      target: "comment",
      level: :info,
      description: "批量拒绝评论: #{count}条"
    )
    redirect_to admin_comments_path, notice: "Successfully rejected #{count} comment(s)."
  rescue => e
    ActivityLog.create!(
      action: "failed",
      target: "comment",
      level: :error,
      description: "批量拒绝评论失败: #{e.message}"
    )
    redirect_to admin_comments_path, alert: "Error rejecting comments: #{e.message}"
  end

  private

  def set_comment
    @comment = Comment.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:author_name, :author_email, :author_url, :content, :status)
  end

  def reply_params
    params.require(:comment).permit(:content)
  end

  def reply_author_name
    CacheableSettings.site_info[:author].to_s.strip
  end

  def reply_author_url
    raw_url = CacheableSettings.site_info[:url].to_s.strip
    return nil if raw_url.blank?

    normalized_url = raw_url.chomp("/")
    normalized_url = "https://#{normalized_url}" unless normalized_url.match?(%r{^https?://})
    normalized_url
  end
end
