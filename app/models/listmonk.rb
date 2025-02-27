require "net/http"
require "json"
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
      # ActivityLog.create!(
      #   action: "newsletter",
      #   target: "newsletter",
      #   level: :info,
      #   description: "Fetch Lists successfully!"
      # )
      JSON.parse(response.body)["data"]["results"]
    else
      ActivityLog.create!(
        action: "newsletter",
        target: "newsletter",
        level: :info,
        description: "Fetch Lists failed! #{response.code} - #{response.body}"
      )
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
      # ActivityLog.create!(
      #   action: "newsletter",
      #   target: "newsletter",
      #   level: :info,
      #   description: "Fetch Templates successfully!"
      # )
      JSON.parse(response.body)["data"]
    else
      ActivityLog.create!(
        action: "newsletter",
        target: "newsletter",
        level: :info,
        description: "Fetch Templates failed! #{response.code} - #{response.body}"
      )
      []
    end
  end

  def create_campaigns(article, site_title)
    uri = URI("#{url}/api/campaigns")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(username, api_key)
    request["Content-Type"] = "application/json"
    request.body = {
      name: article.title,
      subject: "#{article.title} | #{site_title}",
      lists: [ list_id ],
      type: "regular",
      content_type: "html",
      messenger: "email",
      body: article.content.body.to_html,
      send_later: false
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end
    campaign_id = JSON.parse(response.body)["data"]["id"] if response.is_a?(Net::HTTPSuccess)
    if campaign_id
      log_message = "Create Campaign successfully! Title:#{article.title},Campaign ID:#{campaign_id}"
    else
      log_message = "Create Campaign failed! Title:#{article.title},Code:#{response.code} - #{response.body}"
    end
    ActivityLog.create!(
      action: "newsletter",
      target: "newsletter",
      level: :info,
      description: log_message
    )
    campaign_id
  end
  def send_newsletter(article, site_title = "")
    campaign_id = create_campaigns(article, site_title)
    return false unless campaign_id.present?

    uri = URI("#{url}/api/campaigns/#{campaign_id}/status")
    request = Net::HTTP::Put.new(uri)
    request.basic_auth(username, api_key)
    request["Content-Type"] = "application/json"
    request.body = {
      status: "running"
    }.to_json
    # running the campaign
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end
    if response.is_a?(Net::HTTPSuccess)
      log_message = "Send Campaign successfully! Title:#{article.title},Campaign ID:#{campaign_id}"
    else
      log_message = "Send Campaign failed! #{response.code} - #{response.body}"
    end
    ActivityLog.create!(
      action: "newsletter",
      target: "newsletter",
      level: :info,
      description: log_message
    )
  end
end
