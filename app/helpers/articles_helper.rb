require "net/http"
require "json"

module ArticlesHelper
  # Render article content and replace standalone social links with cards.
  #
  # We only transform "standalone" links (e.g. a paragraph that contains only the link),
  # to avoid breaking inline links inside sentences.
  def render_article_content_with_social_cards(article)
    html = if article.html?
      article.rendered_content.to_s
    else
      # ActionText::RichText renders to HTML via #to_s
      article.rendered_content.to_s
    end

    html = html.to_s
    return "".html_safe if html.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    document = fragment.document

    fragment.css("a[href]").each do |a|
      href = a["href"].to_s.strip
      next if href.blank?
      next unless href.match?(%r{\Ahttps?://}i)

      platform = social_platform_for_url(href)
      next unless platform

      container = standalone_link_container_for(a)
      next unless container

      if platform == "twitter"
        uri = safe_parse_uri(href)
        if uri && twitter_status_url?(uri)
          container.replace(build_twitter_embed_card_node(document, uri))
          next
        end
      end

      container.replace(build_social_link_card_node(document, href, platform))
    end

    fragment.to_html.html_safe
  end

  # Generate HTML for source reference information (for RSS feeds)
  def source_reference_html(article)
    return "" unless article.has_source?

    html = '<aside class="source-reference" style="margin-bottom: 1.5rem; padding: 1rem 1.25rem; border-left: 4px solid #6c757d; background: linear-gradient(135deg, #f8f9fa 0%, #f1f3f4 100%); border-radius: 0 8px 8px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">'
    html += '<div style="display: flex; align-items: flex-start; gap: 0.75rem; margin-bottom: 0.75rem;">'
    html += '<i class="fas fa-quote-left" style="color: #6c757d; font-size: 1.25rem; margin-top: 0.125rem; opacity: 0.6;"></i>'
    html += '<div style="flex: 1;">'

    if article.source_author.present?
      html += "<span style=\"font-weight: 600; color: #495057; font-size: 0.95rem;\">#{ERB::Util.html_escape(article.source_author)}</span>"
    end

    html += "</div></div>"

    if article.source_content.present?
      html += '<blockquote style="margin: 0 0 0.75rem 0; padding: 0; color: #495057; font-style: italic; line-height: 1.6; font-size: 0.95rem;">'
      formatted_content = simple_format(article.source_content, {}, wrapper_tag: "span")
      html += formatted_content.to_s
      html += "</blockquote>"
    end

    html += '<div style="display: flex; flex-wrap: wrap; gap: 0.75rem; font-size: 0.85rem;">'

    if article.source_url.present?
      html += "<a href=\"#{ERB::Util.html_escape(article.source_url)}\" target=\"_blank\" rel=\"noopener noreferrer\" style=\"color: #007bff; text-decoration: none; display: inline-flex; align-items: center; gap: 0.375rem; transition: color 0.2s;\">"
      html += '<i class="fas fa-external-link-alt" style="font-size: 0.75rem;"></i>'
      html += "<span>Original</span>"
      html += "</a>"
    end

    if article.source_archive_url.present?
      html += '<span style="color: #dee2e6;">|</span>'
      html += "<a href=\"#{ERB::Util.html_escape(article.source_archive_url)}\" target=\"_blank\" rel=\"noopener noreferrer\" style=\"color: #6c757d; text-decoration: none; display: inline-flex; align-items: center; gap: 0.375rem; transition: color 0.2s;\">"
      html += '<i class="fas fa-archive" style="font-size: 0.75rem;"></i>'
      html += "<span>Archive</span>"
      html += "</a>"
    end

    html += "</div></aside>"
    html.html_safe
  end

  private

  SOCIAL_PLATFORM_RULES = [
    { platform: "twitter",  hosts: %w[twitter.com www.twitter.com x.com www.x.com] },
    { platform: "bluesky",  hosts: %w[bsky.app www.bsky.app] },
    { platform: "youtube",  hosts: %w[youtube.com www.youtube.com youtu.be www.youtu.be] },
    { platform: "instagram", hosts: %w[instagram.com www.instagram.com] },
    { platform: "tiktok",   hosts: %w[tiktok.com www.tiktok.com] },
    { platform: "github",   hosts: %w[github.com www.github.com] },
    { platform: "reddit",   hosts: %w[reddit.com www.reddit.com] },
    { platform: "linkedin", hosts: %w[linkedin.com www.linkedin.com] },
    { platform: "facebook", hosts: %w[facebook.com www.facebook.com] },
    { platform: "telegram", hosts: %w[t.me telegram.me] },
    { platform: "whatsapp", hosts: %w[wa.me www.wa.me whatsapp.com www.whatsapp.com] }
  ].freeze

  PLATFORM_DISPLAY_NAMES = {
    "twitter" => "Twitter / X",
    "bluesky" => "Bluesky",
    "mastodon" => "Mastodon",
    "internet_archive" => "Internet Archive",
    "youtube" => "YouTube",
    "instagram" => "Instagram",
    "tiktok" => "TikTok",
    "github" => "GitHub",
    "reddit" => "Reddit",
    "linkedin" => "LinkedIn",
    "facebook" => "Facebook",
    "telegram" => "Telegram",
    "whatsapp" => "WhatsApp"
  }.freeze

  PLATFORM_ICON_CLASSES = {
    "twitter" => (Crosspost::PLATFORM_ICONS["twitter"] rescue "fa-solid fa-link"),
    "bluesky" => (Crosspost::PLATFORM_ICONS["bluesky"] rescue "fa-solid fa-link"),
    "mastodon" => (Crosspost::PLATFORM_ICONS["mastodon"] rescue "fa-solid fa-link"),
    "internet_archive" => (Crosspost::PLATFORM_ICONS["internet_archive"] rescue "fa-solid fa-link"),
    "youtube" => "fa-brands fa-youtube",
    "instagram" => "fa-brands fa-instagram",
    "tiktok" => "fa-brands fa-tiktok",
    "github" => "fa-brands fa-github",
    "reddit" => "fa-brands fa-reddit",
    "linkedin" => "fa-brands fa-linkedin",
    "facebook" => "fa-brands fa-facebook",
    "telegram" => "fa-brands fa-telegram",
    "whatsapp" => "fa-brands fa-whatsapp"
  }.freeze

  def social_platform_for_url(url)
    uri = safe_parse_uri(url)
    return nil unless uri

    host = uri.host.to_s.downcase
    return nil if host.blank?

    # Special-case Mastodon: instances vary.
    # Heuristic: URLs that look like a status link on a Mastodon instance.
    if mastodon_like_url?(uri)
      return "mastodon"
    end

    rule = SOCIAL_PLATFORM_RULES.find { |r| r[:hosts].include?(host) }
    rule ? rule[:platform] : nil
  end

  def mastodon_like_url?(uri)
    host = uri.host.to_s.downcase
    return false if host.blank?

    # Avoid matching obvious non-mastodon social domains
    return false if %w[twitter.com x.com bsky.app youtube.com youtu.be instagram.com tiktok.com github.com reddit.com linkedin.com facebook.com].include?(host)

    path = uri.path.to_s
    return true if path.match?(%r{\A/@[^/]+/\d+}i)
    return true if path.match?(%r{\A/users/[^/]+/statuses/\d+}i)
    false
  end

  def twitter_status_url?(uri)
    path = uri.path.to_s
    return true if path.match?(%r{/status/\d+}i)
    return true if path.match?(%r{\A/i/web/status/\d+}i)
    false
  end

  def normalized_twitter_status_url(uri)
    # Prefer twitter.com for widest embed compatibility (x.com also works on many setups).
    normalized = uri.dup
    normalized.scheme = "https"
    normalized.host = "twitter.com"
    normalized.query = nil
    normalized.fragment = nil
    normalized.to_s
  rescue StandardError
    uri.to_s
  end

  def safe_parse_uri(url)
    URI.parse(url)
  rescue URI::InvalidURIError
    nil
  end

  def standalone_link_container_for(a)
    # Don't touch links inside common embed blocks / code blocks.
    return nil if a.ancestors.any? { |n| %w[blockquote pre code].include?(n.name) }

    container = a.ancestors.find { |n| %w[p li div].include?(n.name) } || a.parent
    return nil unless container

    # Only replace when container effectively contains just this link (plus whitespace / <br>).
    return nil unless container.css("a").length == 1

    # No significant text outside the link.
    significant_text = container.children.any? do |child|
      child.text? && child.text.to_s.gsub(/\s+/, "").present?
    end
    return nil if significant_text

    # Allow only <a> and <br> element children.
    element_children = container.element_children
    return nil unless element_children.all? { |c| c == a || c.name == "br" }

    # Avoid converting when the link text is part of other content.
    return nil unless container.text.to_s.strip == a.text.to_s.strip

    container
  end

  def build_social_link_card_node(document, href, platform)
    display_name = PLATFORM_DISPLAY_NAMES[platform] || platform.to_s.titleize
    icon_class = PLATFORM_ICON_CLASSES[platform] || "fa-solid fa-link"

    uri = safe_parse_uri(href)
    host = uri&.host.to_s
    pretty_url = begin
      u = uri ? "#{uri.host}#{uri.path}" : href
      u = u[0, 120] + "…" if u.length > 120
      u
    rescue StandardError
      href
    end

    wrapper = Nokogiri::XML::Node.new("div", document)
    wrapper["class"] = "social-link-card social-link-card--#{platform}"

    link = Nokogiri::XML::Node.new("a", document)
    link["class"] = "social-link-card__link"
    link["href"] = href
    link["target"] = "_blank"
    link["rel"] = "noopener noreferrer"

    icon_wrap = Nokogiri::XML::Node.new("div", document)
    icon_wrap["class"] = "social-link-card__icon"
    icon = Nokogiri::XML::Node.new("i", document)
    icon["class"] = icon_class
    icon_wrap.add_child(icon)

    body = Nokogiri::XML::Node.new("div", document)
    body["class"] = "social-link-card__body"

    title = Nokogiri::XML::Node.new("div", document)
    title["class"] = "social-link-card__title"
    title.content = display_name

    meta = Nokogiri::XML::Node.new("div", document)
    meta["class"] = "social-link-card__meta"
    meta.content = host.presence || "external link"

    url_line = Nokogiri::XML::Node.new("div", document)
    url_line["class"] = "social-link-card__url"
    url_line.content = pretty_url

    body.add_child(title)
    body.add_child(meta)
    body.add_child(url_line)

    arrow = Nokogiri::XML::Node.new("div", document)
    arrow["class"] = "social-link-card__arrow"
    arrow_i = Nokogiri::XML::Node.new("i", document)
    arrow_i["class"] = "fa-solid fa-arrow-up-right-from-square"
    arrow.add_child(arrow_i)

    link.add_child(icon_wrap)
    link.add_child(body)
    link.add_child(arrow)
    wrapper.add_child(link)

    wrapper
  end

  def build_twitter_embed_card_node(document, uri)
    href = normalized_twitter_status_url(uri)

    wrapper = Nokogiri::XML::Node.new("div", document)
    wrapper["class"] = "social-link-card social-link-card--embed social-link-card--twitter"

    embed = Nokogiri::XML::Node.new("div", document)
    embed["class"] = "social-link-card__embed"

    # 生成占位符，由客户端 JavaScript 异步加载推文内容
    placeholder = Nokogiri::XML::Node.new("div", document)
    placeholder["class"] = "twitter-tweet-placeholder"
    placeholder["data-controller"] = "twitter-embed"
    placeholder["data-twitter-embed-url-value"] = href
    placeholder["data-twitter-embed-loading-class"] = "twitter-tweet-placeholder--loading"

    # 添加加载指示器
    loading_div = Nokogiri::XML::Node.new("div", document)
    loading_div["class"] = "twitter-tweet-placeholder__loading"
    loading_div.content = "加载推文..."
    placeholder.add_child(loading_div)

    embed.add_child(placeholder)
    wrapper.add_child(embed)
    wrapper
  end

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
        # author_name 是显示名称（昵称），author_url 包含用户名
        author_display_name = data["author_name"] # 显示名称（昵称）
        author_url = data["author_url"] # 完整 URL

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
          author_display_name: author_display_name, # 显示名称（昵称）
          author_username: author_username, # 用户名
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
      # 尝试从 Twitter 的公开用户页面获取头像
      # 使用 x.com 域名（Twitter 的新域名）
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
          # 确保是头像 URL（包含 profile_images 或 twimg.com）
          if avatar_url.match?(%r{(profile_images|twimg\.com|pbs\.twimg\.com)})
            return avatar_url
          end
        end

        # 方法2: 从 JSON-LD 数据中提取
        json_ld_matches = html.scan(/<script[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/m)
        json_ld_matches.each do |json_ld_match|
          begin
            json_data = JSON.parse(json_ld_match[0])
            json_data = [ json_data ] unless json_data.is_a?(Array)

            json_data.each do |item|
              if item.is_a?(Hash)
                # 查找 Person 类型的数据
                if item["@type"] == "Person" && item["image"]
                  avatar_url = item["image"]
                  if avatar_url.is_a?(String) && avatar_url.match?(%r{(profile_images|twimg\.com|pbs\.twimg\.com)})
                    return avatar_url
                  end
                end
                # 也检查 image 字段
                if item["image"] && item["image"].is_a?(String)
                  avatar_url = item["image"]
                  if avatar_url.match?(%r{(profile_images|twimg\.com|pbs\.twimg\.com)})
                    return avatar_url
                  end
                end
              end
            end
          rescue JSON::ParserError
            # 忽略 JSON 解析错误，继续尝试其他方法
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
          # 确保 URL 是完整的（如果不是，补全协议）
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
