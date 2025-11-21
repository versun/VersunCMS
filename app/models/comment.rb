class Comment < ApplicationRecord
  belongs_to :article

  validates :platform, presence: true
  validates :external_id, presence: true
  validates :article_id, presence: true
  validates :external_id, uniqueness: { scope: [ :article_id, :platform ] }

  default_scope { order(published_at: :asc) }

  scope :mastodon, -> { where(platform: "mastodon") }
end
