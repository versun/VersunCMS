class Article < ApplicationRecord
  include PgSearch::Model
  has_rich_text :content
  enum :status, [ :draft, :publish, :schedule, :trash ]

  # serialize :crosspost_urls, Hash, default: {}

  before_validation :generate_slug, if: :slug_empty?
  validates :slug, presence: true, uniqueness: true
  validates :scheduled_at, presence: true, if: :schedule?
  validates :page_order, presence: true, if: :is_page?

  scope :all_posts, -> { where(is_page: false) }
  scope :all_pages, -> { where(is_page: true) }
  scope :published_posts, -> { where(status: :publish, is_page: false) }
  scope :published_pages, -> { where(status: :publish, is_page: true) }
  scope :by_status, ->(status, is_page) { where(status: status, is_page: is_page) }
  # scope :paginate, ->(page, per_page) { offset((page - 1) * per_page).limit(per_page) }
  scope :publishable, -> { where(status: :schedule).where("scheduled_at <= ?", Time.current) }

  before_save :schedule_publication, if: :should_schedule?
  after_save :handle_crosspost, if: -> { Setting.table_exists? }

  multisearchable against: [ :title ]

  def to_param
    slug
  end

  def publish_scheduled
    update(status: :publish, scheduled_at: nil) if should_publish?
  end

  private

  def generate_slug
    self.slug = title.parameterize
  end

  def slug_empty?
    slug.blank?
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
    else
      update_column(:crosspost_urls, {})
    end
  end
end
