class ArchiveArticleJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find_by(id: article_id)
    return unless article
    return unless article.publish?

    settings = ArchiveSetting.instance
    return unless settings.enabled?
    return unless settings.configured?

    article_url = build_article_url(article)

    archive_item = ArchiveItem.find_or_initialize_by(url: ArchiveItem.normalize_url(article_url))
    return if archive_item.completed?

    archive_item.article ||= article
    archive_item.title ||= article.title
    archive_item.status = :pending if archive_item.new_record? || archive_item.failed?
    archive_item.save!

    ArchiveUrlJob.perform_later(archive_item.id)
  end

  private

  def build_article_url(article)
    setting = Setting.first
    base_url = normalize_base_url(setting&.url)
    prefix = Rails.application.config.x.article_route_prefix
    [ base_url.chomp("/"), prefix.to_s.delete_prefix("/"), article.slug ].reject(&:blank?).join("/")
  end

  def normalize_base_url(url)
    url = url.to_s.strip
    url = "http://localhost:3000" if url.blank?
    url = url.delete_suffix("/")
    return url if url.match?(%r{\Ahttps?://}i)
    return url if url.match?(%r{\A[a-z][a-z0-9+\-.]*://}i)
    url = "https://#{url}"
    url
  end
end
