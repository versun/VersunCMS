class NewsletterConfirmationJob < ApplicationJob
  include CacheableSettings
  include SmtpConfigurable
  queue_as :default

  def perform(subscriber_id)
    subscriber = Subscriber.find(subscriber_id)
    site_info = CacheableSettings.site_info
    newsletter_setting = NewsletterSetting.instance

    # 配置 ActionMailer 和准备 SMTP 配置
    if newsletter_setting.enabled? && newsletter_setting.native? && newsletter_setting.configured?
      configure_action_mailer(newsletter_setting)
    end

    mail = NewsletterMailer.confirmation_email(subscriber, site_info)
    
    # 应用 SMTP 配置到邮件对象
    apply_smtp_config_to_mail(mail, newsletter_setting)

    mail.deliver_now
    Rails.logger.info "Successfully sent confirmation email to #{subscriber.email}"
  rescue => e
    Rails.logger.error "Failed to send confirmation email to #{subscriber.email}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if e.backtrace
    raise
  end
end
