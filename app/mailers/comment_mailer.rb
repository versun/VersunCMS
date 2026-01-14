class CommentMailer < ApplicationMailer
  def reply_notification(reply_comment, site_info = nil)
    @reply = reply_comment
    @parent = reply_comment.parent
    @commentable = reply_comment.display_commentable
    @site_info = site_info || CacheableSettings.site_info

    @site_title = @site_info[:title].presence || "Site"
    @commentable_title = @commentable&.title.to_s
    @commentable_path = commentable_path(@commentable)

    site_url = normalized_site_url(@site_info[:url])
    @commentable_url = site_url.present? ? "#{site_url}#{@commentable_path}" : @commentable_path

    mail to: @parent.author_email,
      subject: "New reply to your comment | #{@site_title}"
  end

  private

  def normalized_site_url(raw_url)
    raw = raw_url.to_s.strip
    return "" if raw.blank?

    site_url = raw.chomp("/")
    site_url = "https://#{site_url}" unless site_url.match?(%r{^https?://})
    site_url
  end

  def commentable_path(commentable)
    return "" unless commentable

    helpers = Rails.application.routes.url_helpers
    if commentable.is_a?(Page)
      helpers.page_path(commentable)
    else
      helpers.article_path(commentable)
    end
  end
end
