class AdminController < ApplicationController
  def posts
    @is_page = false
    @scope = Article.all_posts
    @posts = fetch_articles(@scope)
    @path = admin_posts_path
    # render 'admin/article_list'
  end

  def pages
    @is_page = true
    @scope = Article.all_pages
    @posts = fetch_articles(@scope, sort_by: :page_order, is_page: true)
    @path = admin_pages_path
    # render 'admin/article_list'
  end

  private

  def fetch_articles(scope, sort_by: :created_at, is_page: false)
    @page = params[:page].present? ? params[:page].to_i : 1
    @per_page = 20
    @status = params[:status] || "all"

    filtered_posts = filter_by_status(scope, is_page)
    #@total_count = filtered_posts.count
    filtered_posts.paginate(page:@page, per_page:@per_page).order(sort_by => :desc)
  end

  def filter_by_status(posts, is_page)
    case @status
    when "publish", "schedule", "draft", "trash" then posts.by_status(@status.to_sym, is_page)
    else posts
    end
  end
end
