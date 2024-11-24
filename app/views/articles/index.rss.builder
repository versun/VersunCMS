xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title @site[:title]
    xml.description @site[:description]
    xml.link @site[:url]
    xml.author @site[:author]

    @articles.each do |article|
      xml.item do
        xml.title article.title
        xml.description article.content
        xml.pubDate article.created_at.rfc822
        xml.link "#{@site[:url]}/blog/#{article.slug}"
        xml.guid "#{@site[:url]}/blog/#{article.slug}"
        xml.author @site[:author]
      end
    end
  end
end
