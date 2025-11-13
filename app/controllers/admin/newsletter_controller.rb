class Admin::NewsletterController < Admin::BaseController
  def show
    @listmonk = Listmonk.first_or_initialize
    fetch_external_data if @listmonk.persisted? && @listmonk.configured?
    @activity_logs = ActivityLog.track_activity("newsletter")
  end

  def update
    @listmonk = Listmonk.first_or_initialize
    @activity_logs = ActivityLog.track_activity("newsletter")

    if @listmonk.update(listmonk_params)
      redirect_to admin_newsletter_path, notice: "Newsletter settings updated successfully."
    else
      fetch_external_data if @listmonk.configured?
      render :show, alert: @listmonk.errors.full_messages.join(", ")
    end
  end

  private

  def listmonk_params
    params.expect(listmonk: [ :enabled, :username, :api_key, :url, :list_id, :template_id ])
  end

  def fetch_external_data
    @lists = @listmonk.fetch_lists
    @templates = @listmonk.fetch_templates
  rescue => e
    # 如果获取外部数据失败，记录错误但不中断流程
    Rails.logger.error "Failed to fetch external data: #{e.message}"
    @lists = []
    @templates = []
  end
end
