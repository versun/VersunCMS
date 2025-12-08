class PasswordResetJob < ApplicationJob
  include SmtpConfigurable
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    newsletter_setting = NewsletterSetting.instance

    # 配置 ActionMailer（如果 newsletter 已配置）
    if newsletter_setting.enabled? && newsletter_setting.native? && newsletter_setting.configured?
      configure_action_mailer(newsletter_setting)
    end

    mail = PasswordsMailer.reset(user)
    
    # 应用 SMTP 配置到邮件对象
    apply_smtp_config_to_mail(mail, newsletter_setting)

    mail.deliver_now
    Rails.logger.info "Successfully sent password reset email to #{user.email_address}"
  rescue => e
    Rails.logger.error "Failed to send password reset email to #{user.email_address}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if e.backtrace
    raise
  end
end
