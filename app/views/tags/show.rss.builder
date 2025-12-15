xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0",
        "xmlns:content" => "http://purl.org/rss/1.0/modules/content/" do
  xml.channel do
    xml.title "Articles tagged with #{@tag.name} | #{site_settings[:title]}"
    xml.description "Latest articles tagged with #{@tag.name} from #{site_settings[:title]}"
    xml.link tag_url(@tag.slug)
    xml.author site_settings[:author]

    @articles.each do |article|
      xml.item do
        xml.title article.title.presence || article.created_at.strftime("%Y-%m-%d")
        xml.description article.description
        if article.html?
          xml.tag!("content:encoded") { xml.cdata! (article.html_content || "") }
        else
          xml.tag!("content:encoded") { xml.cdata! article.content.to_s }
        end
        xml.pubDate article.created_at.rfc822
        xml.link [ site_settings[:url], Rails.application.config.x.article_route_prefix, article.slug ].reject(&:blank?).join("/")
        xml.guid [ site_settings[:url], Rails.application.config.x.article_route_prefix, article.slug ].reject(&:blank?).join("/")
        xml.author site_settings[:author]
      end
    end
  end
end
