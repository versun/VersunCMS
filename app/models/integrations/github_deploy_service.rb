require "open3"
require "fileutils"

module Integrations
  # Service for deploying static files to GitHub repository
  # Used when static_generation_destination is set to 'github'
  class GithubDeployService
    DEPLOY_DIR = Rails.root.join("tmp", "github_deploy")

    def initialize
      @settings = Setting.first_or_create
    end

    # Deploy static files to GitHub repository
    # @return [Hash] Result with :success and :message keys
    def deploy
      unless github_configured?
        log_activity(:warn, "GitHub 配置不完整：请检查仓库 URL 和 Token")
        return failure("GitHub 配置不完整：请检查仓库 URL 和 Token")
      end

      log_activity(:info, "开始推送静态文件到 GitHub")

      begin
        prepare_deploy_directory
        clone_repository
        clear_repository_files
        copy_static_files
        commit_and_push

        log_activity(:info, "成功推送到 GitHub: #{@settings.github_repo_url}")
        success("成功推送静态文件到 GitHub 仓库")
      rescue => e
        Rails.event.notify "github_deploy_service.deploy_error",
          level: "error",
          component: "GithubDeployService",
          error_message: e.message,
          backtrace: e.backtrace.first(10).join("\n")
        log_activity(:error, "GitHub 推送失败: #{e.message}")
        failure("推送到 GitHub 失败: #{e.message}")
      ensure
        cleanup_deploy_directory
      end
    end

    def github_configured?
      @settings.github_repo_url.present? && @settings.github_token.present?
    end

    private

    def branch
      @settings.github_backup_branch.presence || "main"
    end

    def prepare_deploy_directory
      FileUtils.rm_rf(DEPLOY_DIR)
      FileUtils.mkdir_p(DEPLOY_DIR)
    end

    def cleanup_deploy_directory
      FileUtils.rm_rf(DEPLOY_DIR) if Dir.exist?(DEPLOY_DIR)
    end

    def clone_repository
      repo_url = build_authenticated_url

      # Try clone with specified branch first
      output, status = git("clone", "--depth", "1", "--branch", branch, repo_url, DEPLOY_DIR.to_s)

      unless status.success?
        # Branch might not exist, try default branch then create target branch
        FileUtils.rm_rf(DEPLOY_DIR)
        output, status = git("clone", "--depth", "1", repo_url, DEPLOY_DIR.to_s)
        raise "克隆仓库失败: #{mask_token(output)}" unless status.success?

        Dir.chdir(DEPLOY_DIR) { git("checkout", "-b", branch) }
      end

      # Configure git user
      Dir.chdir(DEPLOY_DIR) do
        git("config", "user.email", "bot@versun.me")
        git("config", "user.name", "Rables Bot")
      end
    end

    def clear_repository_files
      Dir.chdir(DEPLOY_DIR) do
        Dir.glob("*", File::FNM_DOTMATCH)
           .reject { |f| %w[. .. .git].include?(f) }
           .each { |entry| FileUtils.rm_rf(entry) }
      end
    end

    def copy_static_files
      # GitHub mode always uses tmp/static_output directory
      source_dir = StaticGenerator::GITHUB_OUTPUT_DIR
      copied = 0

      StaticGenerator.deployable_items.each do |item|
        source = source_dir.join(item)
        next unless File.exist?(source)

        dest = DEPLOY_DIR.join(item)
        File.directory?(source) ? FileUtils.cp_r(source, dest) : FileUtils.cp(source, dest)
        copied += 1
      end

      Rails.event.notify "github_deploy_service.files_copied",
        level: "info",
        component: "GithubDeployService",
        copied_items: copied,
        source_dir: source_dir.to_s
    end

    def commit_and_push
      Dir.chdir(DEPLOY_DIR) do
        git("add", "-A")

        # Skip if no changes
        output, = git("status", "--porcelain")
        if output.strip.empty?
          Rails.event.notify "github_deploy_service.no_changes",
            level: "info",
            component: "GithubDeployService"
          return
        end

        # Commit
        timestamp = Time.current.strftime("%Y-%m-%d %H:%M:%S")
        output, status = git("commit", "-m", "Deploy - #{timestamp}")
        raise "提交失败: #{mask_token(output)}" unless status.success?

        # Push (with force fallback for first push)
        repo_url = build_authenticated_url
        output, status = git("push", repo_url, branch)

        unless status.success?
          if output.include?("rejected") || output.include?("non-fast-forward")
            output, status = git("push", "--force", repo_url, branch)
          end
          raise "推送失败: #{mask_token(output)}" unless status.success?
        end

        Rails.event.notify "github_deploy_service.pushed",
          level: "info",
          component: "GithubDeployService",
          branch: branch
      end
    end

    def build_authenticated_url
      url = @settings.github_repo_url
      token = @settings.github_token

      case
      when url.start_with?("https://")
        url.sub("https://", "https://#{token}@")
      when url.start_with?("git@")
        url.sub(/git@([^:]+):/, "https://#{token}@\\1/")
      else
        "https://#{token}@github.com/#{url}.git"
      end
    end

    def git(*args)
      # Use array-based arguments to prevent command injection
      # Open3.capture2e with array args doesn't invoke shell
      cmd_for_log = "git #{args.join(' ')}"
      Rails.event.notify "github_deploy_service.git_command",
        level: "debug",
        component: "GithubDeployService",
        command: mask_token(cmd_for_log)
      output, status = Open3.capture2e("git", *args)
      [ output, status ]
    end

    def mask_token(text)
      text.to_s
          .gsub(/ghp_[a-zA-Z0-9]+/, "[REDACTED]")
          .gsub(/github_pat_[a-zA-Z0-9_]+/, "[REDACTED]")
    end

    def log_activity(level, description)
      ActivityLog.create!(
        action: level == :error ? "failed" : "github_deploy",
        target: "github_deploy",
        level: level,
        description: description
      )
    end

    def success(message)
      { success: true, message: message }
    end

    def failure(message)
      { success: false, message: message }
    end
  end
end
