class Setting < ApplicationRecord
  has_rich_text :footer
  before_save :generate_social_links

  SOCIAL_PLATFORMS = {
    github: {
      icon_path: "github.svg"
    },
    twitter: {
      icon_path: "twitter.svg"
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
    },
    rss: {
      icon_path: "rss.svg"
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
