require "net/http"
require "json"

class Listmonk < ApplicationRecord
  validates :api_key, presence: true
  validates :url, presence: true, format: { with: URI.regexp, message: "格式无效" }

  # 获取所有列表
  def fetch_lists
    uri = URI("#{url}/api/lists")
    request = Net::HTTP::Get.new(uri)
    request["X-API-Key"] = api_key

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)["data"]
    else
      []
    end
  end
end
