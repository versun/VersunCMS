class CrosspostSetting < ApplicationRecord
  PLATFORMS = %w[mastodon twitter].freeze

  validates :platform, presence: true,
                      uniqueness: true,
                      inclusion: { in: PLATFORMS }
  validates :server_url, presence: true, if: :mastodon?
  validates :access_token, presence: true, if: :enabled?

  scope :mastodon, -> { find_or_create_by(platform: "mastodon") }
  scope :twitter, -> { find_or_create_by(platform: "twitter") }

  def mastodon?
    platform == "mastodon"
  end

  def twitter?
    platform == "twitter"
  end

  def enabled?
    enabled == true
  end
end
