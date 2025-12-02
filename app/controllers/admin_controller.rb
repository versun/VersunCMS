class AdminController < ApplicationController
  layout "admin"

  def posts
    @scope = Article.all
    @posts = fetch_articles(@scope)
    @path = admin_posts_path
    # render 'admin/article_list'
  end

  def pages
    @scope = Page.all
    @posts = fetch_articles(@scope, sort_by: :page_order)
    @path = admin_pages_path
    # render 'admin/article_list'
  end

  private

  def fetch_articles(scope, sort_by: :created_at)
    @page = params[:page].present? ? params[:page].to_i : 1
    @per_page = 100
    @status = params[:status] || "publish"

    filtered_posts = filter_by_status(scope)
    # @total_count = filtered_posts.count
    filtered_posts.paginate(page: @page, per_page: @per_page).order(sort_by => :desc)
  end

  def filter_by_status(posts)
    case @status
    when "publish", "schedule", "shared", "draft", "trash" then posts.by_status(@status.to_sym)
    else posts
    end
  end
end
