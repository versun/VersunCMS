require "uri"

class NewsletterMailer < ApplicationMailer
  def article_email(article, subscriber, site_info)
    @article = article
    @subscriber = subscriber
    @site_info = site_info
    @newsletter_setting = NewsletterSetting.instance
    @footer = @newsletter_setting.footer

    from_email = @newsletter_setting.from_email
    if from_email.blank?
      Rails.event.notify "newsletter.mailer.missing_from_email",
        level: "error",
        component: "newsletter_mailer",
        fallback_email: "noreply@example.com"
      from_email = "noreply@example.com"
    end

    Rails.event.notify "newsletter.mailer.creating_email",
      level: "info",
      component: "newsletter_mailer",
      recipient: @subscriber.email,
      from_email: from_email,
      article_id: @article.id

    mail_obj = mail(
      to: @subscriber.email,
      from: from_email,
      subject: "#{@article.title} | #{@site_info[:title]}"
    )

    # 验证邮件对象设置
    Rails.event.notify "newsletter.mailer.email_created",
      level: "info",
      component: "newsletter_mailer",
      to: mail_obj.to,
      from: mail_obj.from

    mail_obj
  end

  def confirmation_email(subscriber, site_info)
    @subscriber = subscriber
    @site_info = site_info
    api_uri = URI.parse(ApplicationController.helpers.rails_api_url)
    port = api_uri.port
    port = nil if (api_uri.scheme == "http" && port == 80) || (api_uri.scheme == "https" && port == 443)

    script_name = api_uri.path.presence
    script_name = nil if script_name == "/"

    url_options = { token: subscriber.confirmation_token, host: api_uri.host, protocol: api_uri.scheme }
    url_options[:port] = port if port
    url_options[:script_name] = script_name if script_name

    @confirmation_url = Rails.application.routes.url_helpers.confirm_subscription_url(**url_options)

    newsletter_setting = NewsletterSetting.instance
    from_email = newsletter_setting.from_email || "noreply@example.com"

    mail(
      to: @subscriber.email,
      from: from_email,
      subject: "请确认您的订阅 | #{@site_info[:title]}"
    )
  end
end
