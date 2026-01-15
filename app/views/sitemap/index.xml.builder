xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  raw_site_url = site_settings[:url].to_s.strip
  site_url = raw_site_url.presence&.chomp("/")
  site_url = "https://#{site_url}" if site_url.present? && !site_url.match?(%r{^https?://})

  xml.url do
    xml.loc(site_url.presence || site_settings[:url]) # 网站根 URL
    xml.lastmod Time.now.strftime("%Y-%m-%d") # 最后修改时间
    xml.changefreq "daily" # 更新频率
    xml.priority 1.0 # 优先级
  end

  @pages.each do |post|
    xml.url do
      page_path = "/pages/#{post.slug}"
      page_url = site_url.present? ? "#{site_url}#{page_path}" : page_path
      xml.loc page_url
      xml.lastmod post.updated_at.strftime("%Y-%m-%d")
      xml.changefreq "weekly"
      xml.priority 0.8
    end
  end

  @articles.each do |post|
    xml.url do
      article_path = [ Rails.application.config.x.article_route_prefix, post.slug ].reject(&:blank?).join("/")
      article_path = "/#{article_path}" unless article_path.start_with?("/")
      article_url = site_url.present? ? "#{site_url}#{article_path}" : article_path
      xml.loc article_url
      xml.lastmod post.updated_at.strftime("%Y-%m-%d")
      xml.changefreq "weekly"
      xml.priority 0.8
    end
  end
end
