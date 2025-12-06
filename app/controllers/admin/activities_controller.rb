class Admin::ActivitiesController < Admin::BaseController
  def index
    @activity_logs = ActivityLog.order(created_at: :desc).limit(100)
  end
end
