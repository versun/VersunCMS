class Comment < ApplicationRecord
  belongs_to :article
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: "parent_id", dependent: :destroy

  # Validations for all comments
  validates :author_name, presence: true
  validates :content, presence: true
  validates :article_id, presence: true

  # Validations for external comments
  validates :platform, presence: true, if: :external_comment?
  validates :external_id, presence: true, if: :external_comment?
  validates :external_id, uniqueness: { scope: [ :article_id, :platform ] }, if: :external_comment?

  # Optional URL validation for native comments
  validates :author_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  # Validate that parent comment belongs to the same article
  validate :parent_belongs_to_same_article, if: :parent_id?

  # Scopes
  enum :status, { pending: 0, approved: 1, rejected: 2 }, default: :pending

  scope :local, -> { where(platform: nil) }
  scope :mastodon, -> { where(platform: "mastodon") }
  scope :bluesky, -> { where(platform: "bluesky") }
  scope :twitter, -> { where(platform: "twitter") }
  scope :top_level, -> { where(parent_id: nil) }

  default_scope { order(published_at: :asc) }

  private

  def external_comment?
    platform.present? || external_id.present?
  end

  def parent_belongs_to_same_article
    return unless parent_id?

    # Check if parent exists
    parent_record = Comment.find_by(id: parent_id)
    unless parent_record
      errors.add(:parent_id, "does not exist")
      return
    end

    # Check if parent belongs to the same article
    if parent_record.article_id != article_id
      errors.add(:parent_id, "must belong to the same article")
    end
  end
end
