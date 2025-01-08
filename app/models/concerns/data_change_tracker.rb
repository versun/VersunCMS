module DataChangeTracker
  extend ActiveSupport::Concern

  included do
    after_commit :mark_data_changed
  end

  private

  def mark_data_changed
    ActiveRecord::Base.transaction do
      BackupSetting.first_or_create.update_column(:data_changed, true)
    end
  end

  def mark_data_not_changed
    ActiveRecord::Base.transaction do
      BackupSetting.first_or_create.update_column(:data_changed, false)
    end
  end
end
