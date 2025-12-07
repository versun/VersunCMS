# 确保在应用启动时加载 comment fetch 的定时任务
Rails.application.config.after_initialize do
  # 在应用启动后，确保 comment fetch 的定时任务被正确注册
  # 这确保了即使应用重启，定时任务也会被重新加载
  if Crosspost.table_exists?
    begin
      ScheduledFetchSocialCommentsJob.update_schedule
      Rails.logger.info "Comment fetch schedule initialized on application startup"
    rescue => e
      Rails.logger.error "Failed to initialize comment fetch schedule on startup: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
