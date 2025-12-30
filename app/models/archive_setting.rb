class ArchiveSetting < ApplicationRecord
  belongs_to :git_integration, optional: true

  validates :repo_url, presence: true, if: :enabled?
  validates :branch, presence: true
  validates :ia_access_key, :ia_secret_key, presence: true, if: :auto_submit_to_archive_org?
  validate :git_integration_must_be_configured, if: :enabled?

  def self.instance
    first_or_initialize
  end

  def configured?
    return false unless enabled?
    return false if repo_url.blank?
    return false unless git_integration&.configured?
    true
  end

  def ia_configured?
    ia_access_key.present? && ia_secret_key.present?
  end

  def missing_config_fields
    return [] unless enabled?

    missing = []
    missing << "repo_url" if repo_url.blank?
    missing << "branch" if branch.blank?
    missing << "git_integration" unless git_integration&.configured?
    missing
  end

  private

  def git_integration_must_be_configured
    return if git_integration&.configured?

    errors.add(:git_integration, "must be enabled and configured")
  end
end
