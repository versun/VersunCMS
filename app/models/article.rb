class Article < ApplicationRecord
  # Virtual attributes for crosspost functionality
  attr_accessor :crosspost_mastodon, :crosspost_twitter, :crosspost_bluesky, :crosspost_internet_archive
  # Virtual attributes for newsletter functionality
  attr_accessor :send_newsletter, :resend_newsletter

  has_rich_text :content
  has_many :social_media_posts, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags
  accepts_nested_attributes_for :social_media_posts, allow_destroy: true

  enum :status, [ :draft, :publish, :schedule, :trash, :shared ]
  enum :content_type, { rich_text: "rich_text", html: "html" }, default: "rich_text"

  before_validation :generate_slug
  validates :slug, presence: true, uniqueness: true
  validates :scheduled_at, presence: true, if: :schedule?
  validates :html_content, presence: true, if: -> { html? }
  validate :rich_text_content_presence

  scope :published, -> { where(status: :publish) }
  scope :by_status, ->(status) { where(status: status) }
  # scope :paginate, ->(page, per_page) { offset((page - 1) * per_page).limit(per_page) }
  scope :publishable, -> { where(status: :schedule).where("scheduled_at <= ?", Time.current) }

  before_save :handle_time_zone, if: -> { schedule? && scheduled_at_changed? }
  before_save :cleanup_empty_social_media_posts
  before_save :track_content_changes
  after_save :schedule_publication, if: :should_schedule?
  after_save :handle_crosspost, if: -> { Setting.table_exists? }
  after_save :handle_newsletter, if: -> { Setting.table_exists? }
  after_save :archive_source_url, if: :should_archive_source?
  after_save :trigger_static_generation, if: :should_regenerate_static?
  after_destroy :trigger_static_regeneration_on_destroy

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

  # 根据content_type返回相应的内容
  def rendered_content
    if html?
      html_content
    else
      content
    end
  end

  # 获取内容的纯文本版本（用于社交媒体等）
  def plain_text_content
    if html?
      ActionView::Base.full_sanitizer.sanitize(html_content || "")
    else
      content.present? ? content.to_plain_text : ""
    end
  end

  # 检查是否有引用信息
  def has_source?
    source_url.present?
  end

  # SEO Meta 字段的默认值方法
  def seo_meta_title
    meta_title.presence || title
  end

  def seo_meta_description
    if meta_description.present?
      meta_description
    else
      # 使用文章开头的纯文本，截取前160个字符
      text = plain_text_content
      if text.present?
        # 移除多余的空白字符
        text = text.squish
        # 截取前160个字符，如果超过则在单词边界截断
        if text.length > 160
          text = text[0..156] + "..."
        end
        text
      else
        description
      end
    end
  end

  def seo_meta_image
    if meta_image.present?
      meta_image
    else
      # 尝试从文章内容中获取第一张图片
      image_attachment = first_image_attachment
      if image_attachment
        if image_attachment.is_a?(ActiveStorage::Blob)
          # 返回相对路径，在视图中转换为绝对路径
          Rails.application.routes.url_helpers.rails_blob_path(image_attachment, only_path: true)
        elsif image_attachment.class.name == "ActionText::Attachables::RemoteImage"
          image_attachment.try(:url)
        end
      else
        nil
      end
    end
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

    %w[mastodon twitter bluesky internet_archive].each do |platform|
      should_post = should_crosspost_to?(platform)
      Rails.logger.info "Crosspost check for #{platform}: should_post=#{should_post}"
      CrosspostArticleJob.perform_later(id, platform) if should_post
    end
  end

  def should_send_newsletter?
    Rails.logger.info "Newsletter check start: article_id=#{id}, status=#{status}, publish?=#{publish?}, send_newsletter=#{send_newsletter.inspect}, resend_newsletter=#{resend_newsletter.inspect}"

    unless publish?
      Rails.logger.info "Newsletter check: article is not published, skipping"
      return false
    end

    newsletter_setting = NewsletterSetting.instance
    enabled = newsletter_setting.enabled?
    configured = newsletter_setting.configured?
    missing_fields = newsletter_setting.missing_config_fields

    Rails.logger.info "Newsletter setting: enabled=#{enabled}, configured=#{configured}, provider=#{newsletter_setting.provider}"
    if missing_fields.any?
      Rails.logger.warn "Newsletter missing required fields: #{missing_fields.join(', ')}. Please configure these in Newsletter Settings."
    end

    unless enabled && configured
      Rails.logger.info "Newsletter check: newsletter setting not enabled or not configured, skipping"
      return false
    end

    # 检查 send_newsletter 虚拟属性（用于新文章）
    # Rails check_box 会发送 "1" 当勾选时，"0" 当未勾选时
    # 但也可能收到 true/false 布尔值，或者字符串 "true"/"false"
    send_checked = send_newsletter.to_s == "1" || send_newsletter == true || send_newsletter.to_s == "true"

    # 检查 resend_newsletter 虚拟属性（用于已存在文章）
    resend_checked = resend_newsletter.to_s == "1" || resend_newsletter == true || resend_newsletter.to_s == "true"

    # 只要勾选了任一复选框即发送
    result = send_checked || resend_checked

    Rails.logger.info "Newsletter check result: should_send=#{result}, send_checked=#{send_checked}, resend_checked=#{resend_checked}, send_newsletter_value=#{send_newsletter.inspect}, resend_newsletter_value=#{resend_newsletter.inspect}"

    result
  end

  def handle_newsletter
    Rails.logger.info "handle_newsletter called: article_id=#{id}, status=#{status}"

    unless should_send_newsletter?
      Rails.logger.info "handle_newsletter: should_send_newsletter? returned false, skipping"
      return
    end

    newsletter_setting = NewsletterSetting.instance
    Rails.logger.info "handle_newsletter: sending newsletter, provider=#{newsletter_setting.provider}"

    if newsletter_setting.native?
      Rails.logger.info "handle_newsletter: enqueuing NativeNewsletterSenderJob for article #{id}"
      NativeNewsletterSenderJob.perform_later(id)
    elsif newsletter_setting.listmonk?
      Rails.logger.info "handle_newsletter: enqueuing ListmonkSenderJob for article #{id}"
      ListmonkSenderJob.perform_later(id)
    else
      Rails.logger.warn "handle_newsletter: unknown provider #{newsletter_setting.provider}"
    end
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

  def rich_text_content_presence
    if rich_text?
      text = content.present? ? content.to_plain_text.to_s.strip : ""
      if text.blank?
        errors.add(:content, "can't be blank")
      end
    end
  end

  def should_regenerate_static?
    # Only regenerate if auto-regenerate is enabled for article updates
    return false unless Setting.first_or_create.auto_regenerate_enabled?("article_update")
    
    # Regenerate when status changes to/from published, or when published content changes
    saved_change_to_status? || (publish? && (saved_change_to_title? || saved_change_to_description? || @content_changed))
  end

  def track_content_changes
    # Track content changes before save
    if html?
      # For HTML content type, check the html_content field directly
      @content_changed = html_content_changed?
    else
      # For rich_text, check ActionText body changes
      @content_changed = content.present? && content.body_changed?
    end
  end

  def trigger_static_generation
    GenerateStaticFilesJob.perform_later(type: "article", id: id)
  end

  def trigger_static_regeneration_on_destroy
    # Regenerate index and related pages when article is destroyed
    GenerateStaticFilesJob.perform_later(type: "index")
  end

  def should_archive_source?
    # Archive source URL when it's added/changed and archive_url is empty
    saved_change_to_source_url? && source_url.present? && source_archive_url.blank?
  end

  def archive_source_url
    ArchiveSourceUrlJob.perform_later(id)
  end
end
