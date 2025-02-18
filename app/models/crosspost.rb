class Crosspost < ApplicationRecord
  PLATFORMS = %w[mastodon twitter bluesky listmonk].freeze

  validates :platform, presence: true,
                      uniqueness: true,
                      inclusion: { in: PLATFORMS }

  scope :mastodon, -> { find_or_create_by(platform: "mastodon") }
  scope :twitter, -> { find_or_create_by(platform: "twitter") }
  scope :bluesky, -> { find_or_create_by(platform: "bluesky") }
  scope :listmonk, -> { find_or_create_by(platform: "listmonk") }

  def self.plateforms
    PLATFORMS
  end
  def mastodon?
    platform == "mastodon"
  end

  def twitter?
    platform == "twitter"
  end

  def bluesky?
    platform == "bluesky"
  end

  def listmonk?
    platform == "listmonk"
  end
  def enabled?
    enabled == true
  end
end
