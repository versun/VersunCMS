class Article < ApplicationRecord
  has_rich_text :content
  enum :status, [ :draft, :publish, :schedule, :trash ]

  before_validation :generate_slug, if: :slug_empty?
  validates :slug, presence: true, uniqueness: true
  validates :scheduled_at, presence: true, if: :schedule?
  validates :page_order, presence: true, if: :is_page?

  scope :all_posts, -> { where(is_page: false) }
  scope :all_pages, -> { where(is_page: true) }
  scope :published_posts, -> { where(status: :publish, is_page: false) }
  scope :published_pages, -> { where(status: :publish, is_page: true) }
  scope :by_status, ->(status, is_page) { where(status: status, is_page: is_page) }
  scope :paginate, ->(page, per_page) { offset((page - 1) * per_page).limit(per_page) }
  scope :publishable, -> { where(status: :schedule).where("scheduled_at <= ?", Time.current) }

  before_save :schedule_publication, if: :should_schedule?
  after_save :handle_crosspost, if: :should_crosspost?

  include Article::FullTextSearch
  after_save :find_or_create_article_fts

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
    has_crosspost_enabled = crosspost_mastodon? || crosspost_twitter?
    return false unless publish? && has_crosspost_enabled
    
    crosspost_settings_changed = saved_change_to_crosspost_mastodon? || saved_change_to_crosspost_twitter?
    became_published = saved_change_to_status? && status_previously_was != 'publish'
    
    new_record? || crosspost_settings_changed || became_published

  end
  # def should_crosspost?
  #   # 当是新记录且状态为 publish 时
  #   new_record_condition = new_record? && 
  #     publish? && 
  #     (crosspost_mastodon? || crosspost_twitter?)
    
  #   # 当 crosspost 设置改变且为 publish 状态时
  #   current_crosspost_condition = publish? && 
  #     (saved_change_to_crosspost_mastodon? || saved_change_to_crosspost_twitter?) &&
  #     (crosspost_mastodon? || crosspost_twitter?)
    
  #   # 当状态改为 publish 且有 crosspost 选项被勾选时
  #   status_change_condition = saved_change_to_status? && 
  #     status_previously_was != 'publish' && 
  #     publish? &&
  #     (crosspost_mastodon? || crosspost_twitter?)
    
  #   current_crosspost_condition || status_change_condition
  # end

  def handle_crosspost
    CrosspostArticleJob.perform_later(id) if should_crosspost?
  end
end
