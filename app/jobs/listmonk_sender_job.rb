require "net/http"
require "json"

class ListmonkSenderJob < ApplicationJob
  include CacheableSettings
  queue_as :default

  def perform(article_id)
    article = Article.find(article_id)
    listmonk = Listmonk.first
    ActivityLog.create!(
      action: "started",
      target: "newsletter",
      level: :info,
      description: "Performing newsletter for article #{article.title}"
    )
    return unless listmonk.present? && listmonk.list_id.present? && listmonk.template_id.present?

    listmonk.send_newsletter(article, CacheableSettings.site_info[:title])
  end
end
