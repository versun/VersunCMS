class MigrateLegacyGithubDeploySettings < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:settings)
    return unless table_exists?(:git_integrations)
    return unless column_exists?(:settings, :deploy_provider)

    settings_class = Class.new(ActiveRecord::Base) do
      self.table_name = "settings"
    end

    git_integrations_class = Class.new(ActiveRecord::Base) do
      self.table_name = "git_integrations"
    end

    settings_class.reset_column_information
    git_integrations_class.reset_column_information

    settings = settings_class.first
    return if settings.nil?

    if settings.deploy_provider.blank? && settings.respond_to?(:static_generation_destination) && settings.static_generation_destination == "github"
      settings.deploy_provider = "github"
    end

    if settings.respond_to?(:github_repo_url) && settings.deploy_repo_url.blank?
      settings.deploy_repo_url = settings.github_repo_url
    end

    if settings.respond_to?(:github_backup_branch) && settings.github_backup_branch.present?
      if settings.deploy_branch.blank? || (settings.deploy_branch == "main" && settings.github_backup_branch != "main")
        settings.deploy_branch = settings.github_backup_branch
      end
    end

    settings.save!(validate: false)

    return unless settings.deploy_provider == "github"
    return unless settings.respond_to?(:github_token) && settings.github_token.present?

    github = git_integrations_class.find_or_initialize_by(provider: "github")
    github.name ||= "GitHub"
    github.access_token = settings.github_token if github.access_token.blank?
    github.enabled = true unless github.enabled
    github.save!(validate: false)
  end

  def down
  end
end
