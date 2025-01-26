class ActivityLog < ApplicationRecord
  enum :level, [ :info, :warn, :error ]

  def self.track_activity(action)
    ActivityLog.where(action: action).order(created_at: :desc).limit(10)
  end
end
