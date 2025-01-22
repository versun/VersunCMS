# config/initializers/default_settings.rb
Rails.application.config.after_initialize do
  include Rails.application.routes.url_helpers
  # 使用 Rails.application.executor.wrap 确保在完整的 Rails 环境中执行
  Rails.application.executor.wrap do
    next unless defined?(Setting) # 确保 Setting 模型已加载
    # 检查表是否存在
    next unless ActiveRecord::Base.connection.table_exists?("settings")

    Setting.first_or_create! do |setting|
      setting.title = "My Blog"
      setting.description = "A blog about my life."
      setting.author = "Your Name"
      setting.time_zone = "UTC"
      setting.footer = "&copy; 2025 Your Name. All rights reserved."

      # 设置 URL
      if ENV["SITE_URL"].present?
        setting.url = ENV["SITE_URL"]
      else
        begin
          default_url_options = Rails.application.config.action_mailer.default_url_options ||
                               { host: "localhost", port: 3000 }
          setting.url = root_url(**default_url_options)
        rescue => e
          # 如果 URL 生成失败，使用默认值
          setting.url = "http://localhost:3000"
          Rails.logger.warn "Failed to generate root_url, using default: #{e.message}"
        end
      end
    end
  end
end
