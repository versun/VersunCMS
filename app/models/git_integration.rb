# Git integration model for managing Git provider authentication
# Supports: GitHub, GitLab, Gitea, Codeberg, Bitbucket
class GitIntegration < ApplicationRecord
  require "cgi"

  PROVIDERS = %w[github gitlab gitea codeberg bitbucket].freeze

  validates :provider, presence: true, uniqueness: true, inclusion: { in: PROVIDERS }
  validates :name, presence: true
  validates :access_token, presence: true, if: :enabled?
  validates :server_url, presence: true, if: -> { requires_server_url? && enabled? }
  validates :username, presence: true, if: -> { provider == "bitbucket" && enabled? }

  # encrypts :access_token  # Uncomment when Active Record encryption is configured

  scope :enabled, -> { where(enabled: true) }

  # Provider display names
  PROVIDER_NAMES = {
    "github" => "GitHub",
    "gitlab" => "GitLab",
    "gitea" => "Gitea",
    "codeberg" => "Codeberg",
    "bitbucket" => "Bitbucket"
  }.freeze

  # Default server URLs for providers
  DEFAULT_SERVER_URLS = {
    "github" => "https://github.com",
    "gitlab" => "https://gitlab.com",
    "gitea" => nil, # Requires custom URL
    "codeberg" => "https://codeberg.org",
    "bitbucket" => "https://bitbucket.org"
  }.freeze

  def display_name
    name.presence || PROVIDER_NAMES[provider] || provider.titleize
  end

  def server_base_url
    server_url.presence&.delete_suffix("/") || DEFAULT_SERVER_URLS[provider]
  end

  def requires_server_url?
    provider == "gitea"
  end

  def configured?
    return false unless enabled?
    return false if access_token.blank?
    return false if requires_server_url? && server_url.blank?
    return false if provider == "bitbucket" && username.blank?

    true
  end

  # Build authenticated URL for git operations
  # @param repo_url [String] Repository URL
  # @return [String] Authenticated URL
  def build_authenticated_url(repo_url)
    return repo_url if access_token.blank?

    case provider
    when "github"
      build_https_auth_url(repo_url, "x-access-token:#{access_token}")
    when "gitlab"
      build_https_auth_url(repo_url, "oauth2:#{access_token}")
    when "gitea", "codeberg"
      if username.present?
        build_https_auth_url(repo_url, "#{username}:#{access_token}")
      else
        build_https_auth_url(repo_url, access_token)
      end
    when "bitbucket"
      # Bitbucket uses username:app_password format
      return repo_url if username.blank?
      build_https_auth_url(repo_url, "#{username}:#{access_token}")
    else
      repo_url
    end
  end

  # Mask token in text for safe logging
  def mask_token(text)
    return text if access_token.blank?

    patterns = [
      %r{https://[^@/]+@},
      /ghp_[a-zA-Z0-9]+/,           # GitHub PAT
      /github_pat_[a-zA-Z0-9_]+/,   # GitHub fine-grained PAT
      /glpat-[a-zA-Z0-9\-_]+/,      # GitLab PAT
      /[a-zA-Z0-9]{40}/,            # Generic 40-char token
      Regexp.escape(access_token)
    ]

    result = text.to_s
    patterns.each do |pattern|
      replacement = pattern.is_a?(Regexp) && pattern.source.start_with?("https://") ? "https://[REDACTED]@" : "[REDACTED]"
      result = result.gsub(pattern, replacement)
    end
    result
  end

  # Find or create all provider records
  def self.ensure_all_providers
    PROVIDERS.each do |provider|
      find_or_create_by(provider: provider) do |gi|
        gi.name = PROVIDER_NAMES[provider]
        gi.server_url = DEFAULT_SERVER_URLS[provider]
      end
    end
  end

  # Get the active integration for deployment
  def self.active_for_deploy(provider)
    find_by(provider: provider, enabled: true)
  end

  private

  def escape_userinfo(userinfo)
    userinfo = userinfo.to_s
    return "" if userinfo.empty?

    if userinfo.include?(":")
      user, pass = userinfo.split(":", 2)
      "#{escape_userinfo_part(user)}:#{escape_userinfo_part(pass)}"
    else
      escape_userinfo_part(userinfo)
    end
  end

  def escape_userinfo_part(part)
    CGI.escape(part.to_s).gsub("+", "%20")
  end

  def build_https_auth_url(url, token)
    escaped_userinfo = escape_userinfo(token)

    case
    when url.start_with?("https://")
      url.sub(%r{\Ahttps://[^@/]+@}, "https://").sub("https://", "https://#{escaped_userinfo}@")
    when url.start_with?("git@")
      # Convert SSH to HTTPS with token
      # git@github.com:user/repo.git -> https://token@github.com/user/repo.git
      url.sub(/git@([^:]+):/, "https://#{escaped_userinfo}@\\1/")
    when url.match?(%r{^[^/]+/[^/]+$})
      # Short format: user/repo -> full HTTPS URL
      host = server_base_url&.sub(%r{\Ahttps?://}, "")
      return url if host.blank?
      "https://#{escaped_userinfo}@#{host}/#{url}.git"
    else
      url
    end
  end
end
