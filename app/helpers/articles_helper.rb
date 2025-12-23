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
end
