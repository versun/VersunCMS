class Setting < ApplicationRecord
  has_rich_text :footer
  before_save :parse_social_links_json
  after_save :update_github_backup_schedule, if: :github_backup_settings_changed?

  # Virtual attribute for JSON textarea input
  attr_accessor :social_links_json

  # Check if GitHub backup is fully configured
  def github_backup_configured?
    github_backup_enabled &&
      github_repo_url.present? &&
      github_token.present?
  end

  # Check if initial setup is incomplete
  def self.setup_incomplete?
    User.count.zero? || Setting.first_or_create.setup_completed == false
  end


  private

  def parse_social_links_json
    # If social_links_json is provided, parse it and update social_links
    if social_links_json.present?
      begin
        parsed_data = JSON.parse(social_links_json)
        self.social_links = parsed_data if parsed_data.is_a?(Hash)
      rescue JSON::ParserError => e
        errors.add(:social_links_json, "包含无效的 JSON 格式: #{e.message}")
        throw :abort
      end
    end
  end

  def github_backup_settings_changed?
    saved_change_to_github_backup_enabled? ||
      saved_change_to_github_backup_schedule? ||
      saved_change_to_github_repo_url? ||
      saved_change_to_github_token?
  end

  def update_github_backup_schedule
    ScheduledGithubBackupJob.update_schedule
  end
end
