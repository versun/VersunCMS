module SmtpConfigurable
  extend ActiveSupport::Concern

  private

  def prepare_smtp_config(newsletter_setting)
    return {} unless newsletter_setting&.configured?

    domain = newsletter_setting.smtp_domain.presence || newsletter_setting.from_email&.split("@")&.last
    authentication = newsletter_setting.smtp_authentication.presence || "plain"

    # 转换认证类型为符号
    auth_type = case authentication.to_s.downcase
    when "plain"
      :plain
    when "login"
      :login
    when "cram_md5"
      :cram_md5
    else
      :plain
    end

    {
      address: newsletter_setting.smtp_address,
      port: newsletter_setting.smtp_port || 587,
      domain: domain,
      user_name: newsletter_setting.smtp_user_name,
      password: newsletter_setting.smtp_password,
      authentication: auth_type,
      enable_starttls_auto: newsletter_setting.smtp_enable_starttls != false
    }
  end

  def configure_action_mailer(newsletter_setting)
    return unless newsletter_setting&.configured?

    smtp_settings = prepare_smtp_config(newsletter_setting)

    # 动态配置 ActionMailer 的 SMTP 设置
    # 同时设置类级别和实例级别，确保在后台任务中生效
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = smtp_settings

    # 也设置 Rails 应用配置，确保一致性
    Rails.application.config.action_mailer.delivery_method = :smtp
    Rails.application.config.action_mailer.smtp_settings = smtp_settings

    # 设置默认的 from 地址
    ActionMailer::Base.default from: newsletter_setting.from_email

    Rails.logger.info "ActionMailer configured for SMTP: #{newsletter_setting.smtp_address}:#{newsletter_setting.smtp_port}, from: #{newsletter_setting.from_email}"
    Rails.logger.debug "SMTP settings: #{smtp_settings.except(:password).inspect}"
  end

  def apply_smtp_config_to_mail(mail, newsletter_setting)
    return mail unless newsletter_setting&.enabled? && newsletter_setting.native? && newsletter_setting.configured?

    smtp_config = prepare_smtp_config(newsletter_setting)
    return mail unless smtp_config[:address].present?

    mail.delivery_method(:smtp, smtp_config)
    Rails.logger.info "Mail configured with SMTP: #{newsletter_setting.smtp_address}:#{newsletter_setting.smtp_port}"
    mail
  end
end
