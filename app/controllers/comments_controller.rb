class CommentsController < ApplicationController
  include MathCaptchaVerification
  # Allow unauthenticated users to submit comments
  allow_unauthenticated_access only: [ :create, :options ]

  # Skip CSRF protection for comments from static pages
  skip_forgery_protection only: [ :create, :options ]
  before_action :set_commentable, only: [ :create ]
  before_action :set_cors_headers

  # Handle CORS preflight requests
  def options
    head :ok
  end

  def create
    unless math_captcha_valid?(max: 10)
      ActivityLog.create!(
        action: "failed",
        target: "comment",
        level: :error,
        description: "提交评论验证失败: #{@commentable.class.name}##{@commentable.slug}"
      )

      respond_to do |format|
        format.html do
          if request.xhr? || request.headers["X-Requested-With"] == "XMLHttpRequest"
            render json: { success: false, message: "验证失败：请回答数学题。" }, status: :unprocessable_entity
          else
            redirect_path = determine_redirect_path
            redirect_to redirect_path, alert: "验证失败：请回答数学题。"
          end
        end
        format.json { render json: { success: false, message: "验证失败：请回答数学题。" }, status: :unprocessable_entity }
      end
      return
    end

    @comment = @commentable.comments.build(comment_params)
    @comment.published_at = Time.current
    @comment.status = :pending # Require manual approval

    respond_to do |format|
      if @comment.save
        ActivityLog.create!(
          action: "created",
          target: "comment",
          level: :info,
          description: "提交评论: #{@commentable_type}##{@commentable_id} (#{@comment.author_name})"
        )
        format.html do
          # For AJAX requests, return success response
          if request.xhr? || request.headers["X-Requested-With"] == "XMLHttpRequest"
            render json: { success: true, message: "评论已提交，等待审核后显示。" }, status: :created
          else
            # For regular form submissions, redirect
            redirect_path = determine_redirect_path
            flash[:comment_submitted] = true
            redirect_to redirect_path, notice: "评论已提交，等待审核后显示。"
          end
        end
        format.json { render json: { success: true, message: "评论已提交，等待审核后显示。" }, status: :created }
      else
        ActivityLog.create!(
          action: "failed",
          target: "comment",
          level: :error,
          description: "提交评论失败: #{@comment.errors.full_messages.join(', ')}"
        )
        format.html do
          if request.xhr? || request.headers["X-Requested-With"] == "XMLHttpRequest"
            render json: { success: false, message: "提交评论时出错：#{@comment.errors.full_messages.join('，')}" }, status: :unprocessable_entity
          else
            redirect_path = determine_redirect_path
            redirect_to redirect_path, alert: "提交评论时出错：#{@comment.errors.full_messages.join('，')}"
          end
        end
        format.json { render json: { success: false, message: "提交评论时出错：#{@comment.errors.full_messages.join('，')}" }, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    respond_to do |format|
      format.html do
        if request.xhr? || request.headers["X-Requested-With"] == "XMLHttpRequest"
          render json: { success: false, message: "文章或页面未找到。" }, status: :not_found
        else
          redirect_to root_path, alert: "Article or page not found."
        end
      end
      format.json { render json: { success: false, message: "文章或页面未找到。" }, status: :not_found }
    end
  rescue => e
    Rails.event.notify(
      "comments_controller.comment_creation_error",
      level: "error",
      component: "CommentsController",
      message: e.message,
      backtrace: e.backtrace
    )
    ActivityLog.create!(
      action: "failed",
      target: "comment",
      level: :error,
      description: "提交评论异常: #{e.message}"
    )
    respond_to do |format|
      format.html do
        if request.xhr? || request.headers["X-Requested-With"] == "XMLHttpRequest"
          render json: { success: false, message: "提交评论时发生错误，请稍后重试。" }, status: :internal_server_error
        else
          redirect_to root_path, alert: "An error occurred while submitting your comment. Please try again later."
        end
      end
      format.json { render json: { success: false, message: "提交评论时发生错误，请稍后重试。" }, status: :internal_server_error }
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

  def set_cors_headers
    # Set CORS headers to allow cross-origin requests from static pages
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
    headers["Access-Control-Allow-Headers"] = "Content-Type, X-Requested-With"
    headers["Access-Control-Max-Age"] = "86400" # 24 hours
  end

  def determine_redirect_path
    # If there's a referer and it's a static page, try to redirect back to it
    if request.referer.present?
      referer_uri = URI.parse(request.referer) rescue nil
      if referer_uri && (referer_uri.path.end_with?(".html") || referer_uri.path == "/" || referer_uri.path.start_with?("/page/") || referer_uri.path.start_with?("/pages/") || referer_uri.path.start_with?("/tags/"))
        # It's likely a static page, redirect back to it with success parameter
        redirect_uri = URI.parse(request.referer)
        if redirect_uri.query.present?
          redirect_uri.query += "&comment_submitted=1"
        else
          redirect_uri.query = "comment_submitted=1"
        end
        return redirect_uri.to_s
      end
    end

    # Fallback to dynamic Rails routes
    @commentable.is_a?(Page) ? page_path(@commentable) : article_path(@commentable)
  end
end
