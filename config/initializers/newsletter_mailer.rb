# 动态配置 ActionMailer 以支持 SMTP
Rails.application.config.after_initialize do
  if NewsletterSetting.table_exists?
    newsletter_setting = NewsletterSetting.instance
    
    if newsletter_setting.enabled? && newsletter_setting.native? && newsletter_setting.configured?
      domain = newsletter_setting.smtp_domain.presence || newsletter_setting.from_email&.split("@")&.last
      authentication = newsletter_setting.smtp_authentication.presence || "plain"
      
      Rails.application.config.action_mailer.delivery_method = :smtp
      Rails.application.config.action_mailer.smtp_settings = {
        address: newsletter_setting.smtp_address,
        port: newsletter_setting.smtp_port || 587,
        domain: domain,
        user_name: newsletter_setting.smtp_user_name,
        password: newsletter_setting.smtp_password,
        authentication: authentication.to_sym,
        enable_starttls_auto: newsletter_setting.smtp_enable_starttls != false
      }
      
      # 设置默认的 from 地址
      ActionMailer::Base.default from: newsletter_setting.from_email
    end
  end
rescue => e
  Rails.logger.warn "Failed to configure newsletter mailer: #{e.message}"
end

