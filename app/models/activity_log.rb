class ActivityLog < ApplicationRecord
  include DataChangeTracker
  enum :level, [ :info, :warn, :error ]
end
