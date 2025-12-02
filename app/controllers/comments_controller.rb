class CommentsController < ApplicationController
  before_action :set_article, only: [ :create ]

  def create
    @comment = @article.comments.build(comment_params)
    @comment.published_at = Time.current
    @comment.status = :pending # Require manual approval

    if @comment.save
      redirect_to article_path(@article), flash: { comment_submitted: true }
    else
      redirect_to article_path(@article), alert: "Error submitting comment: #{@comment.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_article
    @article = Article.find_by!(slug: params[:article_id])
  end

  def comment_params
    params.require(:comment).permit(:author_name, :author_url, :content)
  end
end
