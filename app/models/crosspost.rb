class Crosspost < ApplicationRecord
  #  encrypts :access_token, :access_token_secret, :client_id, :client_secret,
  #          :client_key, :api_key, :api_key_secret, :app_password, :username
  PLATFORMS = %w[mastodon twitter bluesky internet_archive].freeze

  PLATFORM_ICONS = {
    "mastodon" => "fa-brands fa-mastodon",
    "twitter" => "fa-brands fa-square-x-twitter",
    "bluesky" => "fa-brands fa-square-bluesky",
    "internet_archive" => "fa-solid fa-archive"
  }.freeze

  validates :platform, presence: true,
                      uniqueness: true,
                      inclusion: { in: PLATFORMS }

  validates :client_key, :client_secret, :access_token, presence: true, if: -> { mastodon? && enabled? }
  validates :access_token, :access_token_secret, :api_key, :api_key_secret, presence: true, if: -> { twitter? && enabled? }
  validates :username, :app_password, presence: true, if: -> { bluesky? && enabled? }
  # Internet Archive 不需要额外的验证字段

  after_save :update_comment_fetch_schedule, if: :comment_fetch_settings_changed?

  scope :mastodon, -> { find_or_create_by(platform: "mastodon") }
  scope :twitter, -> { find_or_create_by(platform: "twitter") }
  scope :bluesky, -> { find_or_create_by(platform: "bluesky") }
  scope :internet_archive, -> { find_or_create_by(platform: "internet_archive") }

  def mastodon?
    platform == "mastodon"
  end

  def twitter?
    platform == "twitter"
  end

  def bluesky?
    platform == "bluesky"
  end

  def internet_archive?
    platform == "internet_archive"
  end

  def enabled?
    enabled == true
  end

  private

  def comment_fetch_settings_changed?
    saved_change_to_enabled? ||
      saved_change_to_auto_fetch_comments? ||
      saved_change_to_comment_fetch_schedule?
  end

  def update_comment_fetch_schedule
    ScheduledFetchSocialCommentsJob.update_schedule
  end
end
