class NewsletterMailer < ApplicationMailer
  def article_email(article, subscriber, site_info)
    @article = article
    @subscriber = subscriber
    @site_info = site_info
    @newsletter_setting = NewsletterSetting.instance
    @footer = @newsletter_setting.footer

    from_email = @newsletter_setting.from_email
    if from_email.blank?
      Rails.logger.error "NewsletterMailer: from_email is blank, using default"
      from_email = "noreply@example.com"
    end

    Rails.logger.info "NewsletterMailer: 创建邮件对象 - 收件人: #{@subscriber.email}, 发件人: #{from_email}"

    mail_obj = mail(
      to: @subscriber.email,
      from: from_email,
      subject: "#{@article.title} | #{@site_info[:title]}"
    )

    # 验证邮件对象设置
    Rails.logger.info "NewsletterMailer: 邮件对象已创建 - TO: #{mail_obj.to.inspect}, FROM: #{mail_obj.from.inspect}"

    mail_obj
  end

  def confirmation_email(subscriber, site_info)
    @subscriber = subscriber
    @site_info = site_info
    @confirmation_url = Rails.application.routes.url_helpers.confirm_subscription_url(
      token: subscriber.confirmation_token,
      host: site_info[:url]&.gsub(/^https?:\/\//, "") || "example.com"
    )

    newsletter_setting = NewsletterSetting.instance
    from_email = newsletter_setting.from_email || "noreply@example.com"

    mail(
      to: @subscriber.email,
      from: from_email,
      subject: "请确认您的订阅 | #{@site_info[:title]}"
    )
  end
end
