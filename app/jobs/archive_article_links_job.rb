class ArchiveArticleLinksJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find_by(id: article_id)
    return unless article

    settings = ArchiveSetting.instance
    return unless settings.enabled?

    # Archive the article URL if enabled
    if settings.auto_archive_published_articles?
      article_url = build_article_url(article)
      queue_archive(article_url, article: article, title: article.title)
    end

    # Archive links from content if enabled
    if settings.auto_archive_article_links?
      extractor = LinkExtractorService.new(article)
      extractor.extract_links.each do |url|
        queue_archive(url, article: article)
      end
    end
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

  def queue_archive(url, article: nil, title: nil)
    normalized_url = ArchiveItem.normalize_url(url)
    archive_item = ArchiveItem.find_or_initialize_by(url: normalized_url)

    return if archive_item.completed? # Already archived

    archive_item.article = article if article && archive_item.article.nil?
    archive_item.title = title if title && archive_item.title.blank?
    archive_item.status = :pending if archive_item.new_record? || archive_item.failed?
    archive_item.save!

    # Queue the job
    ArchiveUrlJob.perform_later(archive_item.id)
  end
end
