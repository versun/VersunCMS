class SocialMediaPost < ApplicationRecord
  belongs_to :article

  validates :platform, presence: true
  # validates :url, presence: true
  validates :platform, uniqueness: { scope: :article_id }

  def icon_path
    Setting::SOCIAL_PLATFORMS[platform.to_sym]&.dig(:icon_path)
  end
end
