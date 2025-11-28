class Admin::CommentsController < AdminController
  before_action :set_comment, only: [ :show, :edit, :update, :destroy, :approve, :reject ]

  def index
    @comments = Comment.includes(:article)

    # Filter by status
    case params[:status]
    when "pending"
      @comments = @comments.pending
    when "approved"
      @comments = @comments.approved
      # else show all
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
    if @comment.update(approved: true)
      redirect_to admin_comments_path, notice: "Comment approved successfully."
    else
      redirect_to admin_comments_path, alert: "Failed to approve comment."
    end
  end

  def reject
    @comment.destroy
    redirect_to admin_comments_path, notice: "Comment rejected and deleted."
  end

  private

  def set_comment
    @comment = Comment.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:author_name, :author_url, :content, :approved)
  end
end
