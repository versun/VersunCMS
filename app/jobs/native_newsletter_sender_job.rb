class NativeNewsletterSenderJob < ApplicationJob
  include CacheableSettings
  include SmtpConfigurable
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

    # 验证 SMTP 配置
    unless smtp_config[:address].present?
      Rails.event.notify "native_newsletter_sender_job.smtp_config_missing",
        level: "error",
        component: "NativeNewsletterSenderJob",
        article_id: article.id
      ActivityLog.create!(
        action: "failed",
        target: "newsletter",
        level: :error,
        description: "SMTP 配置不完整，无法发送邮件"
      )
      return
    end

    relevant_subscribers.each do |subscriber|
      begin
        # 在每次发送前重新配置 ActionMailer，确保使用最新的 SMTP 配置
        configure_action_mailer(newsletter_setting)

        mail = NewsletterMailer.article_email(article, subscriber, site_info)
        Rails.event.notify "native_newsletter_sender_job.sending_email",
          level: "info",
          component: "NativeNewsletterSenderJob",
          subscriber_email: subscriber.email,
          smtp_address: newsletter_setting.smtp_address,
          smtp_port: newsletter_setting.smtp_port

        # 应用 SMTP 配置到邮件对象（与确认邮件使用相同的方法）
        apply_smtp_config_to_mail(mail, newsletter_setting)

        # 记录实际使用的配置（不包含密码）
        Rails.event.notify "native_newsletter_sender_job.smtp_config_applied",
          level: "debug",
          component: "NativeNewsletterSenderJob",
          smtp_settings: smtp_config.except(:password)

        mail.deliver_now
        success_count += 1
        Rails.event.notify "native_newsletter_sender_job.email_sent",
          level: "info",
          component: "NativeNewsletterSenderJob",
          subscriber_email: subscriber.email
      rescue => e
        fail_count += 1
        error_message = "#{e.class.name}: #{e.message}"
        Rails.event.notify "native_newsletter_sender_job.email_failed",
          level: "error",
          component: "NativeNewsletterSenderJob",
          subscriber_email: subscriber.email,
          error_class: e.class.name,
          error_message: e.message,
          smtp_config: smtp_config.except(:password)
        Rails.event.notify "native_newsletter_sender_job.error_backtrace",
          level: "error",
          component: "NativeNewsletterSenderJob",
          backtrace: e.backtrace.join("\n") if e.backtrace
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
end
