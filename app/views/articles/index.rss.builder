xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0",
        "xmlns:content" => "http://purl.org/rss/1.0/modules/content/" do
  xml.channel do
    xml.title site_settings[:title]
    xml.description site_settings[:description]
    xml.link site_settings[:url]
    xml.author site_settings[:author]

    @articles.each do |article|
      xml.item do
        xml.title article.title
        xml.description article.description
        xml.tag!("content:encoded") { xml.cdata! article.content.to_s }
        xml.pubDate article.created_at.rfc822
        xml.link [ site_settings[:url], Rails.application.config.x.article_route_prefix, article.slug ].reject(&:blank?).join("/")
        xml.guid [ site_settings[:url], Rails.application.config.x.article_route_prefix, article.slug ].reject(&:blank?).join("/")
        xml.author site_settings[:author]
      end
    end
  end
end
