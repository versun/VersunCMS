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
    Rails.event.notify "password_reset_job.email_sent",
      level: "info",
      component: "PasswordResetJob",
      user_email: user.email_address
  rescue => e
    Rails.event.notify "password_reset_job.email_failed",
      level: "error",
      component: "PasswordResetJob",
      user_email: user.email_address,
      error_message: e.message
    Rails.event.notify "password_reset_job.error_backtrace",
      level: "error",
      component: "PasswordResetJob",
      backtrace: e.backtrace.join("\n") if e.backtrace
    raise
  end
end
