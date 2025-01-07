class ActivityLog < ApplicationRecord
  enum :level, [ :info, :warn, :error ]
end
