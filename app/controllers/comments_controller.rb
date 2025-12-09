class CommentsController < ApplicationController
  before_action :set_commentable, only: [ :create ]

  def create
    @comment = @commentable.comments.build(comment_params)
    @comment.published_at = Time.current
    @comment.status = :pending # Require manual approval

    if @comment.save
      redirect_path = @commentable.is_a?(Page) ? page_path(@commentable) : article_path(@commentable)
      redirect_to redirect_path, flash: { comment_submitted: true }
    else
      redirect_path = @commentable.is_a?(Page) ? page_path(@commentable) : article_path(@commentable)
      redirect_to redirect_path, alert: "Error submitting comment: #{@comment.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_commentable
    if params[:article_id].present?
      @commentable = Article.find_by!(slug: params[:article_id])
      @article = @commentable # Keep @article for backward compatibility
    elsif params[:page_id].present?
      @commentable = Page.find_by!(slug: params[:page_id])
      @page = @commentable # Set @page for page views
    else
      raise ActiveRecord::RecordNotFound, "No article_id or page_id provided"
    end
  end

  def comment_params
    params.require(:comment).permit(:author_name, :author_url, :content, :parent_id)
  end
end
