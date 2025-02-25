require "net/http"
require "json"

class ListmonkSenderJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find(article_id)
    listmonk = Listmonk.first

    return unless listmonk.present? && listmonk.list_id.present?

    send_to_listmonk(article, listmonk)
  end

  private

  def send_newsletter(article, listmonk)
    return false unless listmonk.list_id.present?

    uri = URI("#{url}/api/campaigns")
    request = Net::HTTP::Post.new(uri)
    request["X-API-Key"] = listmonk.api_key
    request["Content-Type"] = "application/json"
    request.body = {
      name: article.title,
      content_type: "richtext",
      body: article.content,
      list_ids: [listmonk.list_id]
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    response.is_a?(Net::HTTPSuccess)
  end
end
