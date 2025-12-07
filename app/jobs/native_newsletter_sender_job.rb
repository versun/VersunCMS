class NativeNewsletterSenderJob < ApplicationJob
  include CacheableSettings
  queue_as :default

  def perform(article_id)
    article = Article.find(article_id)
    newsletter_setting = NewsletterSetting.instance
    site_info = CacheableSettings.site_info

    return unless newsletter_setting.enabled? && newsletter_setting.native? && newsletter_setting.configured?

    # 在发送邮件前动态配置 ActionMailer，确保使用最新的 SMTP 配置
    configure_action_mailer(newsletter_setting)

    subscribers = Subscriber.active
    return if subscribers.empty?

    # 获取文章的所有tag IDs
    article_tag_ids = article.tags.pluck(:id)

    # 过滤订阅者：只发送给订阅了所有内容的用户，或订阅了文章相关tag的用户
    relevant_subscribers = subscribers.select do |subscriber|
      # 如果订阅者没有订阅任何tag（订阅所有内容），则发送
      if subscriber.subscribed_to_all?
        true
      # 如果订阅者订阅了某些tags，检查文章是否包含这些tags中的至少一个
      elsif subscriber.has_subscriptions?
        subscriber_tag_ids = subscriber.tags.pluck(:id)
        # 文章至少包含一个订阅者订阅的tag
        (article_tag_ids & subscriber_tag_ids).any?
      else
        false
      end
    end

    return if relevant_subscribers.empty?

    ActivityLog.create!(
      action: "initiated",
      target: "newsletter",
      level: :info,
      description: "开始发送原生邮件: #{article.title}，订阅者数量: #{relevant_subscribers.count}（总订阅者: #{subscribers.count}）"
    )

    success_count = 0
    fail_count = 0

    # 准备 SMTP 配置
    smtp_config = prepare_smtp_config(newsletter_setting)
    
    relevant_subscribers.each do |subscriber|
      begin
        mail = NewsletterMailer.article_email(article, subscriber, site_info)
        Rails.logger.info "Sending newsletter email to #{subscriber.email} using SMTP: #{newsletter_setting.smtp_address}:#{newsletter_setting.smtp_port}"
        
        # 直接在邮件对象上设置 SMTP 配置，确保使用正确的设置
        mail.delivery_method(:smtp, smtp_config)
        
        mail.deliver_now
        success_count += 1
        Rails.logger.info "Successfully sent newsletter email to #{subscriber.email}"
      rescue => e
        fail_count += 1
        error_message = "#{e.class.name}: #{e.message}"
        Rails.logger.error "Failed to send newsletter email to #{subscriber.email}: #{error_message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
        ActivityLog.create!(
          action: "failed",
          target: "newsletter",
          level: :error,
          description: "发送邮件失败: #{subscriber.email} - #{error_message}"
        )
      end
    end

    ActivityLog.create!(
      action: "completed",
      target: "newsletter",
      level: :info,
      description: "原生邮件发送完成: #{article.title}，成功: #{success_count}，失败: #{fail_count}"
    )
  end

  private

  def prepare_smtp_config(newsletter_setting)
    return {} unless newsletter_setting.configured?

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
    return unless newsletter_setting.configured?

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
end
