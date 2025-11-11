class ActivityLog < ApplicationRecord
  enum :level, [ :info, :warn, :error ]

  def self.track_activity(target)
    ActivityLog.where(target: target).order(created_at: :desc).limit(10)
  end
end
