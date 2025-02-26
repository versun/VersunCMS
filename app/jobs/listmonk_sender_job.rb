require "net/http"
require "json"

class ListmonkSenderJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find(article_id)
    listmonk = Listmonk.first

    return unless listmonk.present? && listmonk.list_id.present? && listmonk.template_id.present?

    listmonk.send_newsletter(article, site_settings[:title])
  end
end
