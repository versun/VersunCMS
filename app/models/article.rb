class Article < ApplicationRecord
  # Virtual attributes for crosspost functionality
  attr_accessor :crosspost_mastodon, :crosspost_twitter, :crosspost_bluesky
  # Virtual attributes for newsletter functionality
  attr_accessor :send_newsletter, :resend_newsletter

  has_rich_text :content
  has_many :social_media_posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags
  accepts_nested_attributes_for :social_media_posts, allow_destroy: true

  enum :status, [ :draft, :publish, :schedule, :trash, :shared ]

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

  # SQLite原生搜索功能
  scope :search_content, ->(query) {
    return all if query.blank?

    # 简单的LIKE搜索，适用于SQLite
    search_term = "%#{query}%"

    # 搜索标题、slug、描述和内容
    where(
      "title LIKE :term OR
       slug LIKE :term OR
       description LIKE :term OR
       id IN (SELECT record_id FROM action_text_rich_texts
              WHERE record_type = 'Article' AND name = 'content' AND body LIKE :term)",
      term: search_term
    )
  }



  def to_param
    slug
  end

  def publish_scheduled
    update(status: :publish, scheduled_at: nil, created_at: Time.current) if should_publish?
  end

  # 提取文章内容中的第一张图片，用于crosspost
  def first_image_attachment
    return nil unless content.present?
    return nil unless content.body.respond_to?(:attachables)

    # 查找第一个图片附件（支持 ActiveStorage::Blob 和 RemoteImage）
    content.body.attachables.find do |attachable|
      # 检查是否是 ActiveStorage::Blob 且是图片类型
      if attachable.is_a?(ActiveStorage::Blob)
        attachable.content_type&.start_with?("image/")
      # 或者是 RemoteImage 且有有效的URL
      elsif attachable.class.name == "ActionText::Attachables::RemoteImage"
        # 验证RemoteImage有valid URL
        url = attachable.try(:url)
        url.present? && url.is_a?(String)
      else
        false
      end
    end
  end

  # Virtual attribute for tag list (comma-separated tags)
  def tag_list
    tags.map(&:name).join(", ")
  end

  def tag_list=(names)
    self.tags = Tag.find_or_create_by_names(names)
  end

  private

  def generate_slug
    if slug.blank?
      if title.present?
        self.slug = title.parameterize
      else
        # Generate slug from timestamp without setting title
        self.slug = DateTime.current.strftime("%Y-%m-%d-%H-%M").parameterize
      end
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

  def handle_crosspost
    return false unless publish?

    %w[mastodon twitter bluesky].each do |platform|
      should_post = should_crosspost_to?(platform)
      Rails.logger.info "Crosspost check for #{platform}: should_post=#{should_post}"
      CrosspostArticleJob.perform_later(id, platform) if should_post
    end
  end

  def should_send_newsletter?
    return false unless publish?

    # 首先检查 Listmonk 是否启用（后端安全检查）
    newsletter_enabled = Listmonk.first&.enabled?
    return false unless newsletter_enabled

    # 检查 send_newsletter 虚拟属性（用于新文章）
    send_checked = send_newsletter == "1"

    # 检查 resend_newsletter 虚拟属性（用于已存在文章）
    resend_checked = resend_newsletter == "1"

    # 只要勾选了任一复选框即发送
    result = send_checked || resend_checked

    Rails.logger.info "Newsletter check: should_send=#{result}, send_checked=#{send_checked}, resend_checked=#{resend_checked}"

    result
  end

  def handle_newsletter
    ListmonkSenderJob.perform_later(id) if should_send_newsletter?
  end

  def handle_time_zone
    # Make sure scheduled_at is interpreted correctly
    # This ensures Rails knows this time is already in the application time zone
    self.scheduled_at = scheduled_at.in_time_zone(CacheableSettings.site_info[:time_zone]).utc if scheduled_at.present?
  end

  def should_crosspost_to?(platform)
    # 首先检查平台是否启用（后端安全检查）
    platform_enabled = Crosspost.find_by(platform: platform)&.enabled?
    return false unless platform_enabled

    # 检查 crosspost
    crosspost_checked = send("crosspost_#{platform}") == "1"

    # 只要勾选了任一复选框即发布
    crosspost_checked
  end

  def cleanup_empty_social_media_posts
    social_media_posts.each do |post|
      post.mark_for_destruction if post.url.blank?
    end
  end
end
