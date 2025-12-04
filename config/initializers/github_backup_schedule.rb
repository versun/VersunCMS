# 确保在应用启动时加载 GitHub backup 的定时任务
Rails.application.config.after_initialize do
  # 在应用启动后，确保 GitHub backup 的定时任务被正确注册
  # 这确保了即使应用重启，定时任务也会被重新加载
  if Setting.table_exists?
    begin
      ScheduledGithubBackupJob.update_schedule
      Rails.logger.info "GitHub backup schedule initialized on application startup"
    rescue => e
      Rails.logger.error "Failed to initialize GitHub backup schedule on startup: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
