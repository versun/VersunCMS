class Admin::RedirectsController < Admin::BaseController
  before_action :set_redirect, only: [ :edit, :update, :destroy ]

  def index
    @redirects = Redirect.order(created_at: :desc)
  end

  def new
    @redirect = Redirect.new
  end

  def create
    @redirect = Redirect.new(redirect_params)

    if @redirect.save
      ActivityLog.create!(
        action: "created",
        target: "redirect",
        level: :info,
        description: "创建重定向: #{@redirect.regex} -> #{@redirect.replacement}"
      )
      redirect_to admin_redirects_path, notice: "Redirect was successfully created."
    else
      ActivityLog.create!(
        action: "failed",
        target: "redirect",
        level: :error,
        description: "创建重定向失败: #{@redirect.errors.full_messages.join(', ')}"
      )
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @redirect.update(redirect_params)
      ActivityLog.create!(
        action: "updated",
        target: "redirect",
        level: :info,
        description: "更新重定向: #{@redirect.regex} -> #{@redirect.replacement}"
      )
      redirect_to admin_redirects_path, notice: "Redirect was successfully updated."
    else
      ActivityLog.create!(
        action: "failed",
        target: "redirect",
        level: :error,
        description: "更新重定向失败: #{@redirect.errors.full_messages.join(', ')}"
      )
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    redirect_info = "#{@redirect.regex} -> #{@redirect.replacement}"
    @redirect.destroy!
    ActivityLog.create!(
      action: "deleted",
      target: "redirect",
      level: :info,
      description: "删除重定向: #{redirect_info}"
    )
    redirect_to admin_redirects_path, status: :see_other, notice: "Redirect was successfully deleted."
  end

  private

  def set_redirect
    @redirect = Redirect.find(params[:id])
  end

  def redirect_params
    params.require(:redirect).permit(:regex, :replacement, :permanent, :enabled)
  end
end
