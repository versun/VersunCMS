class Admin::CommentsController < AdminController
  before_action :set_comment, only: [ :show, :edit, :update, :destroy, :approve, :reject ]

  def index
    @comments = Comment.includes(:article)

    # Filter by status
    # Filter by status
    if params[:status].present? && Comment.statuses.key?(params[:status])
      @comments = @comments.where(status: params[:status])
    end

    @comments = @comments.order(created_at: :desc).paginate(page: params[:page], per_page: 30)
  end

  def show
  end

  def edit
  end

  def update
    if @comment.update(comment_params)
      redirect_to admin_comments_path, notice: "Comment updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @comment.destroy
    redirect_to admin_comments_path, notice: "Comment deleted successfully."
  end

  def approve
    if @comment.approved!
      redirect_to admin_comments_path, notice: "Comment approved successfully."
    else
      redirect_to admin_comments_path, alert: "Failed to approve comment."
    end
  end

  def reject
    if @comment.rejected!
      redirect_to admin_comments_path, notice: "Comment rejected."
    else
      redirect_to admin_comments_path, alert: "Failed to reject comment."
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

    redirect_to admin_comments_path, notice: "Successfully deleted #{count} comment(s)."
  rescue => e
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

    redirect_to admin_comments_path, notice: "Successfully approved #{count} comment(s)."
  rescue => e
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

    redirect_to admin_comments_path, notice: "Successfully rejected #{count} comment(s)."
  rescue => e
    redirect_to admin_comments_path, alert: "Error rejecting comments: #{e.message}"
  end

  private

  def set_comment
    @comment = Comment.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:author_name, :author_url, :content, :status)
  end
end
