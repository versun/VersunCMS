class BackupLog < ApplicationRecord
  enum :status, { started: 0, completed: 1, failed: 2 }
  
  validates :status, presence: true
  validates :message, presence: true
end
