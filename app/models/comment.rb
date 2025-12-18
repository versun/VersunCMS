class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  # Keep belongs_to :article for backward compatibility
  belongs_to :article, optional: true
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: "parent_id", dependent: :destroy

  # Validations for all comments
  validates :author_name, presence: true
  validates :content, presence: true
  validates :commentable_id, presence: true
  validates :commentable_type, presence: true

  # Validations for external comments
  validates :platform, presence: true, if: :external_comment?
  validates :external_id, presence: true, if: :external_comment?
  validates :external_id, uniqueness: { scope: [ :commentable_type, :commentable_id, :platform ] }, if: :external_comment?

  # Optional URL validation for native comments
  validates :author_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  # Validate that parent comment belongs to the same commentable
  validate :parent_belongs_to_same_commentable, if: :parent_id?

  # Scopes
  enum :status, { pending: 0, approved: 1, rejected: 2 }, default: :pending

  scope :local, -> { where(platform: nil) }
  scope :mastodon, -> { where(platform: "mastodon") }
  scope :bluesky, -> { where(platform: "bluesky") }
  scope :twitter, -> { where(platform: "twitter") }
  scope :top_level, -> { where(parent_id: nil) }

  default_scope { order(published_at: :asc) }

  # Trigger static generation when comment is created, updated, or status changes
  after_save :schedule_static_generation, if: :should_regenerate_static?

  private

  def external_comment?
    platform.present? || external_id.present?
  end

  def parent_belongs_to_same_commentable
    return unless parent_id?

    # Check if parent exists
    parent_record = Comment.find_by(id: parent_id)
    unless parent_record
      errors.add(:parent_id, "does not exist")
      return
    end

    # Check if parent belongs to the same commentable
    if parent_record.commentable_type != commentable_type || parent_record.commentable_id != commentable_id
      errors.add(:parent_id, "must belong to the same #{commentable_type}")
    end
  end

  def should_regenerate_static?
    # Only regenerate if auto-regenerate is enabled for comment updates
    return false unless Setting.first_or_create.auto_regenerate_enabled?("comment_update")

    # Trigger when:
    # 1. Comment is created and already approved
    # 2. Comment status changes (approved, rejected, etc.)
    # 3. Comment content or other fields change (if approved)
    if new_record?
      # New comment that is already approved
      approved?
    else
      # Existing comment: trigger on status change or content update (if approved)
      saved_change_to_status? || (approved? && (saved_change_to_content? || saved_change_to_author_name? || saved_change_to_author_url?))
    end
  end

  def schedule_static_generation
    # Schedule debounced static generation for the commentable
    GenerateStaticFilesJob.schedule_debounced(
      type: commentable_type.downcase,
      id: commentable_id
    )
  end
end
