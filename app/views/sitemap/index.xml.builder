xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/1.1" do
  xml.url do
    xml.loc site_settings[:url] # 网站根 URL
    xml.lastmod Time.now.strftime("%Y-%m-%d") # 最后修改时间
    xml.changefreq "daily" # 更新频率
    xml.priority 1.0 # 优先级
  end

  @pages.each do |post|
    xml.url do
      xml.loc "#{site_settings[:url]}/pages/#{post.slug}"
      xml.lastmod post.updated_at.strftime("%Y-%m-%d")
      xml.changefreq "weekly"
      xml.priority 0.8
    end
  end

  @articles.each do |post|
    xml.url do
      xml.loc [ site_settings[:url], Rails.application.config.article_route_prefix, post.slug ].reject(&:blank?).join("/")
      xml.lastmod post.updated_at.strftime("%Y-%m-%d")
      xml.changefreq "weekly"
      xml.priority 0.8
    end
  end
end
