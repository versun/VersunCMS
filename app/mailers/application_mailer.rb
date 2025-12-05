class ApplicationMailer < ActionMailer::Base
  layout "mailer"

  def self.default_from_email
    if NewsletterSetting.table_exists?
      setting = NewsletterSetting.instance
      return setting.from_email if setting.enabled? && setting.native? && setting.configured?
    end
    "from@example.com"
  end

  default from: default_from_email
end
