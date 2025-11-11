class Admin::BaseController < ApplicationController
  # 统一的Admin基类控制器
  # 所有后台管理控制器都应该继承此类

  # before_action :authenticate_user!
  # before_action :require_admin_privileges
  layout 'admin'
  private

  def require_admin_privileges
    # 这里可以添加权限检查逻辑
    # 例如：redirect_to root_path unless Current.user&.admin?
  end

  def fetch_articles(scope, sort_by: :created_at)
    @page = params[:page].present? ? params[:page].to_i : 1
    @per_page = 20
    @status = params[:status] || "publish"

    filtered_posts = filter_by_status(scope)
    filtered_posts.paginate(page: @page, per_page: @per_page).order(sort_by => :desc)
  end

  def filter_by_status(posts)
    case @status
    when "publish", "schedule", "shared", "draft", "trash"
      posts.by_status(@status.to_sym)
    else
      posts
    end
  end
end
