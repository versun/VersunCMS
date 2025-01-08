class Setting < ApplicationRecord
  include DataChangeTracker
  include CacheableSettings
  has_rich_text :footer
  # after_initialize :set_default, if: :new_record?
  before_save :generate_social_links

  # Handle static_files as JSON
  # attribute :static_files, :json, default: {}

  SOCIAL_PLATFORMS = {
    github: {
      icon_path: "fontawesome/github.svg"
    },
    twitter: {
      icon_path: "fontawesome/x-twitter.svg"
    },
    mastodon: {
      icon_path: "fontawesome/mastodon.svg"
    },
    bluesky: {
      icon_path: "fontawesome/bluesky.svg"
    },
    linkedin: {
      icon_path: "fontawesome/linkedin.svg"
    },
    instagram: {
      icon_path: "fontawesome/instagram.svg"
    },
    youtube: {
      icon_path: "fontawesome/youtube.svg"
    },
    facebook: {
      icon_path: "fontawesome/facebook.svg"
    },
    medium: {
      icon_path: "fontawesome/medium.svg"
    },
    stackoverflow: {
      icon_path: "fontawesome/stack-overflow.svg"
    }
  }.freeze

  STATIC_FILES = {
    "robots.txt" => {
      placeholder: "User-agent: *\nDisallow: /admin"
    },
    "humans.txt" => {
      placeholder: "/* TEAM */\nAuthor: Your Name\nSite: your-site.com\nLocation: Your City, Country"
    },
    "security.txt" => {
      placeholder: "Contact: mailto:security@your-site.com\nExpires: 2025-12-31T23:59:59.000Z\nPreferred-Languages: en, zh"
    },
    "ads.txt" => {
      placeholder: "google.com, pub-0000000000000000, DIRECT, f08c47fec0942fa0"
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
