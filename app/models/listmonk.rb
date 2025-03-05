require "net/http"
require "json"
class Listmonk < ApplicationRecord
  validates :api_key, presence: true
  validates :username, presence: true
  validates :url, presence: true, format: { with: URI.regexp, message: "格式无效" }

  # 获取所有列表
  def fetch_lists
    begin
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
        raise "Fetch Lists failed! #{response.code} - #{response.body}"
      end
    rescue => e
      ActivityLog.create!(
        action: "newsletter",
        target: "newsletter",
        level: :error,
        description: e.message
      )
      []
    end
  end

  def fetch_templates
    begin
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
        raise "Fetch Template failed! #{response.code} - #{response.body}"
      end
    rescue => e
      ActivityLog.create!(
        action: "newsletter",
        target: "newsletter",
        level: :error,
        description: e.message
      )
      []
    end
  end

  def create_campaigns(article, site_title)
    begin
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
        body: article.content.to_s,
        send_later: false
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      campaign_id = JSON.parse(response.body)["data"]["id"] if response.is_a?(Net::HTTPSuccess)

      if campaign_id
        ActivityLog.create!(
          action: "newsletter",
          target: "newsletter",
          level: :info,
          description: "Create Campaign successfully! Title:#{article.title},Campaign ID:#{campaign_id}"
        )
      else
        raise "Create Campaign failed! Title:#{article.title},Code:#{response.code} - #{response.body}"
      end

      campaign_id
    rescue => e
      ActivityLog.create!(
        action: "newsletter",
        target: "newsletter",
        level: :error,
        description: e.message
      )
      nil
    end
  end

  def send_newsletter(article, site_title = "")
    begin
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
        ActivityLog.create!(
          action: "newsletter",
          target: "newsletter",
          level: :info,
          description: "Send Campaign successfully! Title:#{article.title},Campaign ID:#{campaign_id}"
        )
      else
        raise "Send Campaign failed! #{response.code} - #{response.body}"
      end

      true
    rescue => e
      ActivityLog.create!(
        action: "newsletter",
        target: "newsletter",
        level: :error,
        description: e.message
      )
      nil
    end
  end
end
