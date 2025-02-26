require "net/http"
require "json" #54XoGQ4XLSNA0sWRfzMu60p1sk6RXUsI
class Listmonk < ApplicationRecord
  validates :api_key, presence: true
  validates :username, presence: true
  validates :url, presence: true, format: { with: URI.regexp, message: "格式无效" }

  # 获取所有列表
  def fetch_lists
    uri = URI("#{url}/api/lists")
    request = Net::HTTP::Get.new(uri)
    request.basic_auth(username, api_key)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)["data"]["results"]
    else
      []
    end
  end

  def fetch_templates
    uri = URI("#{url}/api/templates")
    request = Net::HTTP::Get.new(uri)
    request.basic_auth(username, api_key)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)["data"]
    else
      []
    end
  end

  def send_newsletter(article,site_title = "")
    uri = URI("#{url}/api/campaigns")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(username, api_key)
    request["Content-Type"] = "application/json"
    request.body = {
      name: article.title,
      subject: "#{article.title} | #{site_title}",
      content_type: "html",
      messenger: article.content,
      lists: [list_id],
      send_later: false,
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    response.is_a?(Net::HTTPSuccess)
  end
end
