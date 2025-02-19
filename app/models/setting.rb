class Setting < ApplicationRecord
  include CacheableSettings
  has_rich_text :footer
  # after_initialize :set_default, if: :new_record?
  before_save :generate_social_links

  # Handle static_files as JSON
  # attribute :static_files, :json, default: {}

  SOCIAL_PLATFORMS = {
    github: {
      icon_path: "github.svg"
    },
    twitter: {
      icon_path: "x-twitter.svg"
    },
    mastodon: {
      icon_path: "mastodon.svg"
    },
    bluesky: {
      icon_path: "bluesky.svg"
    },
    linkedin: {
      icon_path: "linkedin.svg"
    },
    instagram: {
      icon_path: "instagram.svg"
    },
    youtube: {
      icon_path: "youtube.svg"
    },
    facebook: {
      icon_path: "facebook.svg"
    },
    medium: {
      icon_path: "medium.svg"
    },
    stackoverflow: {
      icon_path: "stack-overflow.svg"
    },
    status_page: {
      icon_path: "status.svg"
    },
    web_analytics: {
      icon_path: "chart.svg"
    }
  }.freeze

  private

  def generate_social_links
    return unless social_links.is_a?(Hash)

    social_links.each do |platform, data|
      next if data["url"].blank? || !SOCIAL_PLATFORMS[platform.to_sym]
      data["icon_path"] = SOCIAL_PLATFORMS[platform.to_sym][:icon_path]
    end
  end
end
