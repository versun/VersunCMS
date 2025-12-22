class Setting < ApplicationRecord
  has_rich_text :footer
  before_validation :set_default_local_generation_path
  before_save :parse_social_links_json
  after_save :trigger_static_generation, if: :should_regenerate_static?

  # Virtual attribute for JSON textarea input
  attr_accessor :social_links_json

  # Validate local_generation_path is absolute path
  validate :validate_local_generation_path, if: -> { deploy_provider_effective == "local" && local_generation_path.present? }

  def deploy_provider_effective
    return deploy_provider if deploy_provider.present?
    return "github" if static_generation_destination == "github"

    "local"
  end

  def deploys_to_git?
    provider = deploy_provider_effective
    provider.present? && provider != "local"
  end

  # Check if initial setup is incomplete
  def self.setup_incomplete?
    User.count.zero? || Setting.first_or_create.setup_completed == false
  end

  # Check if a specific trigger is enabled for auto-regeneration
  def auto_regenerate_enabled?(trigger)
    triggers = auto_regenerate_triggers || []
    triggers.include?(trigger.to_s)
  end

  # Convert static_generation_delay string to ActiveSupport::Duration
  # Returns duration object for use with job scheduling
  def generation_delay_duration
    case static_generation_delay
    when "0s"
      0.seconds
    when "30s"
      30.seconds
    when "2m"
      2.minutes
    when "5m"
      5.minutes
    when "15m"
      15.minutes
    else
      2.minutes # default fallback
    end
  end

  private

  def set_default_local_generation_path
    if deploy_provider_effective == "local" && local_generation_path.blank?
      self.local_generation_path = Rails.root.join("public").to_s
    end
  end

  def validate_local_generation_path
    # Check if path is absolute (starts with / on Unix or C:\ on Windows)
    unless local_generation_path.start_with?("/") || local_generation_path.match?(/^[A-Za-z]:[\\\/]/)
      errors.add(:local_generation_path, "必须是绝对路径，不能使用相对路径")
    end
  end

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

  # Check if settings that affect static pages have changed
  def should_regenerate_static?
    # Regenerate when footer or other layout-affecting settings change
    # Note: footer is ActionText (has_rich_text), so when it changes, Setting's updated_at also changes
    # We check for changes in fields that affect static page layout
    # For footer, we check if updated_at changed but other non-layout fields didn't change
    layout_fields_changed = saved_change_to_title? ||
      saved_change_to_description? ||
      saved_change_to_custom_css? ||
      saved_change_to_head_code? ||
      saved_change_to_tool_code? ||
      saved_change_to_giscus?

    # If layout fields changed, definitely regenerate
    return true if layout_fields_changed

    # If only updated_at changed (and no other tracked fields), it might be footer
    # Check if time_zone or other non-layout fields changed - if not, assume footer changed
    non_layout_fields_changed = saved_change_to_time_zone? || saved_change_to_url? || saved_change_to_author?

    # If updated_at changed but no tracked fields changed, assume footer or social_links changed
    saved_change_to_updated_at? && !non_layout_fields_changed
  end

  def trigger_static_generation
    # Regenerate all static pages when footer or layout settings change
    GenerateStaticFilesJob.schedule(type: "all")
  end
end
