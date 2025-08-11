class Article < ApplicationRecord
  has_rich_text :content
  has_many :social_media_posts, dependent: :destroy
  accepts_nested_attributes_for :social_media_posts, allow_destroy: true

  enum :status, [ :draft, :publish, :schedule, :trash, :shared ]

  before_validation :generate_title
  before_validation :generate_slug
  validates :slug, presence: true, uniqueness: true
  validates :scheduled_at, presence: true, if: :schedule?

  scope :published, -> { where(status: :publish) }
  scope :by_status, ->(status) { where(status: status) }
  # scope :paginate, ->(page, per_page) { offset((page - 1) * per_page).limit(per_page) }
  scope :publishable, -> { where(status: :schedule).where("scheduled_at <= ?", Time.current) }

  before_save :handle_time_zone, if: -> { schedule? && scheduled_at_changed? }
  before_save :cleanup_empty_social_media_posts
  after_save :schedule_publication, if: :should_schedule?
  after_save :handle_crosspost, if: -> { Setting.table_exists? }
  after_save :handle_newsletter, if: -> { Setting.table_exists? }

  if defined?(ENABLE_ALGOLIASEARCH)
    include AlgoliaSearch
    algoliasearch if: :should_index? do
      attribute :title, :slug, :description, :plain_content, :links
      attribute :plain_content do
        text = content.to_plain_text
        algolia_max_characters = ENV.fetch("ALGOLIA_MAX_CHARACTERS", "3500").to_i
        if text.size > algolia_max_characters
          text = text.truncate(algolia_max_characters)
        end
        text
      end
      attribute :links do
        doc = Nokogiri::HTML.fragment(content.to_trix_html)
        links = doc.css("a").map { |link| link["href"] }.compact
        links.uniq
      end
      searchableAttributes [ "title", "slug", "description", "plain_content", "links" ]
    end

  else

    include PgSearch::Model
    pg_search_scope :search_content,
                    against: [ :title, :slug, :description ],
                    associated_against: {
                      rich_text_content: [ :body ]
                    },
                    using: {
                      tsearch: {
                        prefix: true,
                        any_word: true,
                        dictionary: "simple"
                      },
                      trigram: {
                        threshold: 0.3
                      }
                    }
  end

  def should_index?
      status == "publish" || status == "shared"
  end

  def to_param
    slug
  end

  def publish_scheduled
    update(status: :publish, scheduled_at: nil, created_at: Time.current) if should_publish?
  end

  private

  def generate_title
    self.title = DateTime.current.strftime("%Y-%m-%d %H:%M") if title.blank?
  end

  def generate_slug
    if slug.blank?
      self.slug = title.parameterize
    end

    # Remove dots from slug if present
    self.slug = slug.gsub(".", "") if slug.include?(".")
  end

  def should_publish?
    schedule? && scheduled_at <= Time.current
  end

  def should_schedule?
    schedule? # && scheduled_at_changed?
  end

  def schedule_publication
    Rails.logger.info "Scheduling publication for article #{id} at #{scheduled_at}"
    PublishScheduledArticlesJob.schedule_at(self)
  end

  # def should_crosspost?
  #
  #   has_crosspost_enabled = crosspost_mastodon? || crosspost_twitter? || crosspost_bluesky?
  #   return false unless publish? && has_crosspost_enabled
  #
  #   any_crosspost_enabled_changed_to_true = saved_change_to_crosspost_mastodon? || saved_change_to_crosspost_twitter? || saved_change_to_crosspost_bluesky?
  #   became_published = saved_change_to_status? && status_previously_was != "publish" # 防止每次内容更新都触发
  #
  #   any_crosspost_enabled_changed_to_true || became_published
  # end

  def handle_crosspost
    return false unless publish?
    return false unless crosspost_mastodon? || crosspost_twitter? || crosspost_bluesky?

    became_published = saved_change_to_status? && status_previously_was != "publish" # 防止每次内容更新都触发
    first_post_to_mastodon = crosspost_mastodon? && became_published
    first_post_to_twitter = crosspost_twitter? && became_published
    first_post_to_bluesky = crosspost_bluesky? && became_published
    re_post_to_mastodon = crosspost_mastodon? && saved_change_to_crosspost_mastodon? # 已经确定是publish状态，所以不需要再次检查
    re_post_to_twitter = crosspost_twitter? && saved_change_to_crosspost_twitter? # 已经确定是publish状态，所以不需要再次检查
    re_post_to_bluesky = crosspost_bluesky? && saved_change_to_crosspost_bluesky? # 已经确定是publish状态，所以不需要再次检查

    CrosspostArticleJob.perform_later(id, "mastodon") if first_post_to_mastodon || re_post_to_mastodon
    CrosspostArticleJob.perform_later(id, "twitter") if first_post_to_twitter || re_post_to_twitter
    CrosspostArticleJob.perform_later(id, "bluesky") if first_post_to_bluesky || re_post_to_bluesky
  end

  def should_send_newsletter?
    return false unless publish?
    return false unless Listmonk.first&.enabled?

    became_published = saved_change_to_status? && status_previously_was != "publish"
    first_send = send_newsletter? && became_published
    re_send = send_newsletter? && saved_change_to_send_newsletter?

    first_send || re_send
  end

  # 提取文章内容中的第一张图片，用于crosspost
  def first_image_attachment
    return nil unless content.present?

    # 从Action Text内容中获取所有附件
    attachments = content.body.attachments

    # 找到第一个图片附件
    attachments.find do |attachment|
      blob = attachment.blob
      blob&.content_type&.start_with?("image/")
    end&.blob
  end

  def handle_newsletter
    ListmonkSenderJob.perform_later(id) if should_send_newsletter?
  end

  def handle_time_zone
    # Make sure scheduled_at is interpreted correctly
    # This ensures Rails knows this time is already in the application time zone
    self.scheduled_at = scheduled_at.in_time_zone(CacheableSettings.site_info[:time_zone]).utc if scheduled_at.present?
  end

  def cleanup_empty_social_media_posts
    social_media_posts.each do |post|
      post.mark_for_destruction if post.url.blank?
    end
  end
end
