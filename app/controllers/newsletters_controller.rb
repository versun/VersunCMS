class NewslettersController < ApplicationController
  before_action :set_listmonk, only: [ :edit ]

  def edit
    if @listmonk.api_key.present? && @listmonk.url.present? && @listmonk.username.present?
      @lists = @listmonk.fetch_lists
      @templates = @listmonk.fetch_templates
      @selected_list = @listmonk.list_id
      @selected_template = @listmonk.template_id
    end
    @activity_logs = ActivityLog.track_activity("newsletter")
  end

  def update
    set_listmonk
    @activity_logs = ActivityLog.track_activity("newsletter")

    if @listmonk.update(listmonk_params)
      redirect_to newsletter_path, notice: "Listmonk settings updated."
    else
      render :edit
    end
  end

  private

  def set_listmonk
    @listmonk = Listmonk.first_or_initialize
  end

  def listmonk_params
    params.expect(listmonk: [ :enabled, :username, :api_key, :url, :list_id, :template_id ])
  end
end
