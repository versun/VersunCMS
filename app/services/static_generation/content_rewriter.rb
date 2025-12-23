module StaticGeneration
  class ContentRewriter
    def initialize(site_url:, resolve_signed_id:)
      @site_url = site_url.to_s.chomp("/")
      @resolve_signed_id = resolve_signed_id
    end

    def rewrite_html(html)
      return html if html.blank?

      html = rewrite_active_storage_urls(html)
      html = normalize_upload_hosts(html)
      html = rewrite_action_text_attachment_urls(html)
      add_lazy_loading_to_images(html)
    end

    def rewrite_rss(xml)
      return xml if xml.blank?

      xml = xml.gsub(%r{(https?://[^/]+)?/rails/active_storage/(blobs|representations)/(redirect/)?([^/"'\s]+)/[^"'\s]+}) do |match|
        signed_id = Regexp.last_match(4)
        static_path = @resolve_signed_id.call(signed_id, match)
        to_absolute_url(static_path)
      end

      xml = xml.gsub(/<action-text-attachment([^>]*)url="([^"]+)"/) do
        attrs = Regexp.last_match(1)
        original_url = Regexp.last_match(2)
        new_url = to_absolute_url(rewrite_attachment_url(original_url))
        "<action-text-attachment#{attrs}url=\"#{new_url}\""
      end

      xml = xml.gsub(/<action-text-attachment([^>]*)url='([^']+)'/) do
        attrs = Regexp.last_match(1)
        original_url = Regexp.last_match(2)
        new_url = to_absolute_url(rewrite_attachment_url(original_url))
        "<action-text-attachment#{attrs}url='#{new_url}'"
      end

      xml.gsub(%r{<img([^>]*)src="([^"]+)"}) do
        attrs = Regexp.last_match(1)
        original_src = Regexp.last_match(2)
        new_src = to_absolute_url(rewrite_attachment_url(original_src))
        "<img#{attrs}src=\"#{new_src}\""
      end
    end

    private

    def rewrite_active_storage_urls(html)
      html.gsub(%r{(https?://[^/]+)?/rails/active_storage/(blobs|representations)/(redirect/)?([^/"'\s]+)/[^"'\s]+}) do |match|
        signed_id = Regexp.last_match(4)
        @resolve_signed_id.call(signed_id, match)
      end
    end

    def normalize_upload_hosts(html)
      html.gsub(%r{https?://[^/]+(/uploads/[^"'\s]+)}) do
        Regexp.last_match(1)
      end
    end

    def rewrite_action_text_attachment_urls(html)
      html = html.gsub(/<action-text-attachment([^>]*)url="([^"]+)"/) do
        attrs = Regexp.last_match(1)
        original_url = Regexp.last_match(2)
        new_url = rewrite_attachment_url(original_url)
        "<action-text-attachment#{attrs}url=\"#{new_url}\""
      end

      html.gsub(/<action-text-attachment([^>]*)url='([^']+)'/) do
        attrs = Regexp.last_match(1)
        original_url = Regexp.last_match(2)
        new_url = rewrite_attachment_url(original_url)
        "<action-text-attachment#{attrs}url='#{new_url}'"
      end
    end

    def rewrite_attachment_url(original_url)
      return original_url if original_url.blank?
      return original_url if original_url.start_with?("/uploads/")

      match = original_url.match(%r{(?:https?://[^/]+)?/rails/active_storage/(blobs|representations)/(redirect/)?([^/"'\s]+)/})
      return original_url unless match

      signed_id = match[3]
      @resolve_signed_id.call(signed_id, original_url)
    end

    def add_lazy_loading_to_images(html)
      html.gsub(/<img\s+([^>]*?)(\s*\/?>)/i) do |match|
        attrs = Regexp.last_match(1)
        closing = Regexp.last_match(2)

        if attrs.include?("loading=")
          match
        else
          "<img #{attrs} loading=\"lazy\" decoding=\"async\"#{closing}"
        end
      end
    end

    def to_absolute_url(path_or_url)
      return path_or_url if path_or_url.blank?
      return path_or_url if path_or_url.start_with?("http")
      return path_or_url unless path_or_url.start_with?("/")
      return path_or_url if @site_url.blank?

      "#{@site_url}#{path_or_url}"
    end
  end
end
