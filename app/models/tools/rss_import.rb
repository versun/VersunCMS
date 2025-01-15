module Tools
  class RssImport
    require "feedjira"
    require "cgi"
    require "open-uri"
    def initialize(file)
      @file = file
      @error_message = nil
    end

    def import_data
      feed = Feedjira.parse(open(@file).read)

      feed.entries.each do |item|
        # slug = item.title ? item.title.parameterize : item.published
        if item.url.nil?
          next
        end

        encoded_link = item.url
        decoded_link = CGI.unescape(encoded_link)
        slug = decoded_link.split("/").last
        content = ActionText::Content.new(item.content)
        description = content.to_plain_text.slice(0, 500)
        content.to_rendered_html_with_layout
        # get all images in the content and download them and then add them to the article content
        doc = Nokogiri::HTML(content.to_s)

        doc.css("img").each do |img|
          src = img["src"]
          next unless src

          URI.open(src) do |io|
            blob = ActiveStorage::Blob.create_and_upload!(
              io: io,
              filename: src.split("/").last,
              content_type: io.content_type
            )
            content.attachables << blob

            # Update image URL in content
            attachment = ActionText::Attachment.from_attachable(blob)

            attachment.node["url"] = blob.url
            img.replace(attachment.node.to_html)
          end
        end

        content = doc.to_html
        Article.create(status: :publish,
                      title: item.title || item.published,
                      content: content,
                      created_at: item.published,
                      slug: slug,
                      description: description
                      )
      end
      true
    rescue StandardError => e
      @error_message = e.message
      false
    end

    def error_message
      @error_message
    end
  end
end
