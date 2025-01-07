module DataChangeTracker
  extend ActiveSupport::Concern

  included do
    after_commit :mark_data_changed
  end

  private

  def mark_data_changed
    BackupSetting.instance.update(data_changed: true)
  end

  def mark_data_not_changed
    BackupSetting.instance.update(data_changed: false)
  end
end
