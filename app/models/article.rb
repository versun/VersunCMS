class Article < ApplicationRecord
  include PgSearch::Model
  multisearchable against: [ :title, :content ]
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

  before_save :schedule_publication, if: :should_schedule?
  before_save :cleanup_empty_social_media_posts
  after_save :handle_crosspost, if: -> { Setting.table_exists? }

  # 配置单表搜索作用域
  pg_search_scope :search_content,
                  against: :title,
                  associated_against: {
                    rich_text_content: :body
                  },
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: "english"
                    },
                    trigram: {
                      threshold: 0.3
                    }
                  }

  def to_param
    slug
  end

  def publish_scheduled
    update(status: :publish, scheduled_at: nil) if should_publish?
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
    schedule? && scheduled_at_changed?
  end

  def schedule_publication
    Rails.logger.info "Scheduling publication for article #{id} at #{scheduled_at}"
    PublishScheduledArticlesJob.schedule_at(self)
  end

  def should_crosspost?
    has_crosspost_enabled = crosspost_mastodon? || crosspost_twitter? || crosspost_bluesky?
    return false unless publish? && has_crosspost_enabled

    crossposts_changed = saved_change_to_crosspost_mastodon? || saved_change_to_crosspost_twitter? || saved_change_to_crosspost_bluesky?
    became_published = saved_change_to_status? && status_previously_was != "publish"

    new_record? || crossposts_changed || became_published
  end

  def handle_crosspost
    if should_crosspost?
      CrosspostArticleJob.perform_later(id)
    end
  end

  def cleanup_empty_social_media_posts
    social_media_posts.each do |post|
      post.mark_for_destruction if post.url.blank?
    end
  end
end
