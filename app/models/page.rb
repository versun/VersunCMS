class Page < ApplicationRecord
  has_rich_text :content
  has_many :comments, as: :commentable, dependent: :destroy
  enum :status, [ :draft, :publish, :schedule, :trash, :shared ]
  enum :content_type, { rich_text: "rich_text", html: "html" }, default: "rich_text"

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :redirect_url, url: true, allow_blank: true
  validates :html_content, presence: true, if: -> { html? }
  validate :rich_text_content_presence

  scope :published, -> { where(status: :publish) }
  scope :by_status, ->(status) { where(status: status) }

  before_save :track_content_changes
  after_save :trigger_static_generation, if: :should_regenerate_static?
  after_destroy :trigger_static_regeneration_on_destroy

  def to_param
    slug
  end

  def redirect?
    redirect_url.present?
  end

  # 根据content_type返回相应的内容
  def rendered_content
    if html?
      html_content
    else
      content
    end
  end

  private

  def rich_text_content_presence
    if rich_text?
      text = content.present? ? content.to_plain_text.to_s.strip : ""
      if text.blank?
        errors.add(:content, "can't be blank")
      end
    end
  end

  def should_regenerate_static?
    # Only regenerate if auto-regenerate is enabled for page updates
    return false unless Setting.first_or_create.auto_regenerate_enabled?("page_update")

    saved_change_to_status? || (publish? && (saved_change_to_title? || @content_changed))
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
    GenerateStaticFilesJob.schedule(type: "page", id: id)
  end

  def trigger_static_regeneration_on_destroy
    GenerateStaticFilesJob.schedule(type: "sitemap")
  end
end
