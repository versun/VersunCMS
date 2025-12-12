require "net/http"
require "json"

module Api
  class TwitterController < ApplicationController
    # 允许未认证访问（因为推文是公开内容）
    allow_unauthenticated_access

    def oembed
      tweet_url = params[:url]
      
      if tweet_url.blank?
        render json: { error: "URL parameter is required" }, status: :bad_request
        return
      end

      # 使用 helper 方法获取推文内容
      tweet_content = fetch_twitter_oembed_content(tweet_url)

      if tweet_content
        render json: tweet_content
      else
        render json: { error: "Failed to fetch tweet content" }, status: :service_unavailable
      end
    end

    private

    def fetch_twitter_oembed_content(tweet_url)
      return nil if tweet_url.blank?

      begin
        # Twitter oEmbed API
        oembed_url = "https://publish.twitter.com/oembed"
        uri = URI(oembed_url)
        uri.query = URI.encode_www_form(url: tweet_url, omit_script: true, dnt: true)
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 3
        http.read_timeout = 3
        
        request = Net::HTTP::Get.new(uri)
        response = http.request(request)
        
        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)
          html = data["html"]
          
          # 解析 HTML 提取文本内容
          doc = Nokogiri::HTML::DocumentFragment.parse(html)
          
          # 提取推文文本（通常在 <p> 标签中）
          text = doc.css("p").map(&:text).join(" ").strip
          
          # 从 oEmbed API 的 JSON 响应中获取作者信息
          author_display_name = data["author_name"]
          author_url = data["author_url"]
          
          # 从 author_url 提取用户名（username）
          author_username = nil
          if author_url
            match = author_url.match(%r{twitter\.com/([^/]+)})
            author_username = match[1] if match
          end
          
          # 如果无法从 JSON 获取，尝试从 HTML 中提取（降级方案）
          if author_username.blank?
            author_link = doc.css("blockquote a").find { |a| a["href"]&.match?(%r{twitter\.com/([^/]+)}) }
            if author_link
              match = author_link["href"].match(%r{twitter\.com/([^/]+)})
              author_username = match[1] if match
            end
          end
          
          # 尝试从 HTML 中的 <img> 标签提取头像
          author_avatar = nil
          avatar_imgs = doc.css("blockquote img, blockquote a img")
          avatar_img = avatar_imgs.find { |img| 
            src = img["src"].to_s
            src.match?(%r{(twimg\.com|pbs\.twimg\.com).*profile_images}) && 
            !src.match?(%r{(emoji|icon|default_profile)}) 
          }
          
          if avatar_img
            author_avatar = avatar_img["src"]
          end
          
          # 如果 HTML 中没有头像，尝试使用 Twitter 公开 API 获取用户头像
          if author_avatar.blank? && author_username
            author_avatar = fetch_twitter_user_avatar(author_username)
          end
          
          # 如果还是找不到，使用默认头像
          if author_avatar.blank?
            author_avatar = "https://abs.twimg.com/sticky/default_profile_images/default_profile_normal.png"
          end
          
          {
            text: text.presence || "推文内容",
            author_display_name: author_display_name,
            author_username: author_username,
            author_url: author_url,
            author_avatar: author_avatar
          }
        else
          Rails.logger.warn "Twitter oEmbed API failed: #{response.code}"
          nil
        end
      rescue => e
        Rails.logger.error "Error fetching Twitter oEmbed: #{e.message}"
        nil
      end
    end

    def fetch_twitter_user_avatar(username)
      return nil if username.blank?

      begin
        user_url = "https://x.com/#{username}"
        uri = URI(user_url)
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 3
        http.read_timeout = 3
        
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        
        response = http.request(request)
        
        if response.is_a?(Net::HTTPSuccess)
          html = response.body
          
          # 方法1: 从 meta 标签中提取 og:image
          meta_match = html.match(/<meta[^>]*property=["']og:image["'][^>]*content=["']([^"']+)["']/i)
          if meta_match
            avatar_url = meta_match[1]
            if avatar_url.match?(%r{(profile_images|twimg\.com|pbs\.twimg\.com)})
              return avatar_url
            end
          end
          
          # 方法2: 从 JSON-LD 数据中提取
          json_ld_matches = html.scan(/<script[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/m)
          json_ld_matches.each do |json_ld_match|
            begin
              json_data = JSON.parse(json_ld_match[0])
              json_data = [json_data] unless json_data.is_a?(Array)
              
              json_data.each do |item|
                if item.is_a?(Hash)
                  if item["@type"] == "Person" && item["image"]
                    avatar_url = item["image"]
                    if avatar_url.is_a?(String) && avatar_url.match?(%r{(profile_images|twimg\.com|pbs\.twimg\.com)})
                      return avatar_url
                    end
                  end
                  if item["image"] && item["image"].is_a?(String)
                    avatar_url = item["image"]
                    if avatar_url.match?(%r{(profile_images|twimg\.com|pbs\.twimg\.com)})
                      return avatar_url
                    end
                  end
                end
              end
            rescue JSON::ParserError
            end
          end
          
          # 方法3: 从 HTML 中查找所有包含 profile_images 的图片
          doc = Nokogiri::HTML(html)
          avatar_imgs = doc.css('img[src*="profile_images"], img[src*="twimg.com"]')
          avatar_img = avatar_imgs.find { |img|
            src = img["src"].to_s
            src.match?(%r{(profile_images|twimg\.com|pbs\.twimg\.com)}) && 
            !src.match?(%r{(default_profile|emoji|icon|banner)})
          }
          
          if avatar_img
            avatar_url = avatar_img["src"]
            if avatar_url.start_with?("//")
              avatar_url = "https:#{avatar_url}"
            elsif avatar_url.start_with?("/")
              avatar_url = "https://x.com#{avatar_url}"
            end
            return avatar_url
          end
        end
      rescue => e
        Rails.logger.error "Error fetching Twitter user avatar for #{username}: #{e.message}"
      end
      
      nil
    end
  end
end
