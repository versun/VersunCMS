class Crosspost < ApplicationRecord
  #  encrypts :access_token, :access_token_secret, :client_id, :client_secret,
  #          :client_key, :api_key, :api_key_secret, :app_password, :username
  PLATFORMS = %w[mastodon twitter bluesky].freeze

  validates :platform, presence: true,
                      uniqueness: true,
                      inclusion: { in: PLATFORMS }

  validates :client_key, :client_secret, :access_token, presence: true, if: -> { mastodon? && enabled? }
  validates :access_token, :access_token_secret, :api_key, :api_key_secret, presence: true, if: -> { twitter? && enabled? }
  validates :username, :app_password, presence: true, if: -> { bluesky? && enabled? }

  scope :mastodon, -> { find_or_create_by(platform: "mastodon") }
  scope :twitter, -> { find_or_create_by(platform: "twitter") }
  scope :bluesky, -> { find_or_create_by(platform: "bluesky") }

  def mastodon?
    platform == "mastodon"
  end

  def twitter?
    platform == "twitter"
  end

  def bluesky?
    platform == "bluesky"
  end

  def enabled?
    enabled == true
  end
end
