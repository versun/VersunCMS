class Comment < ApplicationRecord
  belongs_to :article

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

  # Scopes
  enum :status, { pending: 0, approved: 1, rejected: 2 }, default: :pending

  scope :local, -> { where(platform: nil) }
  scope :mastodon, -> { where(platform: "mastodon") }
  scope :bluesky, -> { where(platform: "bluesky") }
  scope :twitter, -> { where(platform: "twitter") }

  default_scope { order(published_at: :asc) }

  private

  def external_comment?
    platform.present? || external_id.present?
  end
end
