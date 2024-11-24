class Setting < ApplicationRecord
  has_rich_text :footer
  # after_initialize :set_default, if: :new_record?
  before_save :generate_social_links
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

  private

  def set_default
    self.title ||= "John Doe's Blog"
    self.description ||= "A blog about my life."
    self.author ||= "John Doe"
    self.url ||= "https://example.com"
    self.time_zone ||= "UTC"
    # self.footer ||= "Copyright © 2021 John Doe"
    # self.custom_css ||= ""
    # self.social_links ||= {}
  end

  def generate_social_links
    return unless social_links.is_a?(Hash)

    social_links.each do |platform, data|
      next if data["url"].blank? || !SOCIAL_PLATFORMS[platform.to_sym]
      # data["platform"] = platform
      data["icon_path"] = SOCIAL_PLATFORMS[platform.to_sym][:icon_path]
    end
  end
end
