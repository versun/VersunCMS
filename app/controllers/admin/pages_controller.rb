class Admin::PagesController < Admin::BaseController
  before_action :set_page, only: [ :show, :edit, :update, :destroy, :reorder ]

  def index
    @scope = Page.all
    @pages = fetch_articles(@scope, sort_by: :page_order)
    @path = admin_pages_path
  end

  def show
  end

  def new
    @page = Page.new(comment: true)
  end

  def edit
  end

  def create
    @page = Page.new(page_params)

    respond_to do |format|
      if @page.save
        ActivityLog.create!(
          action: "created",
          target: "page",
          level: :info,
          description: "创建页面: #{@page.title}"
        )
        refresh_pages
        format.html { redirect_to admin_pages_path, notice: "Page was successfully created." }
        format.json { render :show, status: :created, location: @page }
      else
        ActivityLog.create!(
          action: "failed",
          target: "page",
          level: :error,
          description: "创建页面失败: #{@page.errors.full_messages.join(', ')}"
        )
        format.html { render :new }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @page.update(page_params)
        ActivityLog.create!(
          action: "updated",
          target: "page",
          level: :info,
          description: "更新页面: #{@page.title}"
        )
        refresh_pages
        format.html { redirect_to admin_pages_path, notice: "Page was successfully updated." }
        format.json { render :show, status: :ok, location: @page }
      else
        ActivityLog.create!(
          action: "failed",
          target: "page",
          level: :error,
          description: "更新页面失败: #{@page.title} - #{@page.errors.full_messages.join(', ')}"
        )
        format.html { render :edit }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    page_title = @page.title
    @page.destroy!
    ActivityLog.create!(
      action: "deleted",
      target: "page",
      level: :info,
      description: "删除页面: #{page_title}"
    )
    refresh_pages

    respond_to do |format|
      format.html { redirect_to admin_pages_path, status: :see_other, notice: "Page was successfully deleted." }
      format.json { head :no_content }
    end
  end

  def reorder
    if @page.insert_at(params[:position].to_i)
      ActivityLog.create!(
        action: "updated",
        target: "page",
        level: :info,
        description: "调整页面顺序: #{@page.title} -> 位置#{params[:position]}"
      )
      head :ok
    else
      ActivityLog.create!(
        action: "failed",
        target: "page",
        level: :error,
        description: "调整页面顺序失败: #{@page.title}"
      )
      head :unprocessable_entity
    end
  end

  private

  def after_batch_action
    refresh_pages
  end

  private

  def set_page
    @page = Page.find_by!(slug: params[:id])
  end

  def page_params
    params.require(:page).permit(:title, :content, :html_content, :content_type, :slug, :page_order, :meta_description, :redirect_url, :status, :comment)
  end

  def refresh_pages
    # 更新页面缓存或执行其他必要的刷新操作
  end
end
