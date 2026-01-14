require "net/http"
require "json"

class ListmonkSenderJob < ApplicationJob
  include CacheableSettings
  queue_as :default

  def perform(article_id)
    article = Article.find(article_id)
    listmonk = Listmonk.first
    ActivityLog.log!(
      action: :started,
      target: :newsletter,
      level: :info,
      title: article.title,
      slug: article.slug,
      mode: "listmonk"
    )
    return unless listmonk.present? && listmonk.list_id.present? && listmonk.template_id.present?

    listmonk.send_newsletter(article, CacheableSettings.site_info[:title])
  end
end
