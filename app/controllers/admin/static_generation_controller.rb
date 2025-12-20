class Admin::StaticGenerationController < Admin::BaseController
  def create
    GenerateStaticFilesJob.schedule(type: "all")

    ActivityLog.create!(
      action: "queued",
      target: "static_generation",
      level: :info,
      description: "静态文件生成任务已加入队列"
    )

    redirect_back fallback_location: admin_root_path,
                  notice: "静态文件生成任务已加入队列，请在 Activity 页面查看生成进度。"
  end
end
