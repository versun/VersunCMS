# 确保在应用启动时加载 comment fetch 的定时任务
Rails.application.config.after_initialize do
  # 在应用启动后，确保 comment fetch 的定时任务被正确注册
  # 这确保了即使应用重启，定时任务也会被重新加载
  if Crosspost.table_exists?
    begin
      ScheduledFetchSocialCommentsJob.update_schedule
      Rails.event.notify "comment_fetch.schedule.initialized",
        level: "info",
        component: "comment_fetch_schedule"
    rescue => e
      Rails.event.notify "comment_fetch.schedule.initialization_failed",
        level: "error",
        component: "comment_fetch_schedule",
        error_message: e.message,
        error_class: e.class.name,
        backtrace: e.backtrace.join("\n")
    end
  end
end
