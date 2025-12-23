require "open3"
require "fileutils"
require "pathname"
require "tmpdir"

module Services
  # Generic Git deploy service for deploying static files to any Git provider
  # Supports: GitHub, GitLab, Gitea, Codeberg, Bitbucket
  class GitDeployService
    def initialize
      @settings = Setting.first_or_create
    end

    # Deploy static files to Git repository
    # @return [Hash] Result with :success and :message keys
    def deploy
      unless deploy_configured?
        log_activity(:warn, "Git 部署配置不完整：请检查仓库 URL 和认证设置")
        return failure("Git 部署配置不完整：请检查仓库 URL 和认证设置")
      end

      log_activity(:info, "开始推送静态文件到 #{provider_name}")

      begin
        prepare_deploy_directory
        clone_repository
        clear_repository_files
        copy_static_files
        commit_and_push

        log_activity(:info, "成功推送到 #{provider_name}: #{@settings.deploy_repo_url}")
        success("成功推送静态文件到 #{provider_name} 仓库")
      rescue => e
        Rails.event.notify "git_deploy_service.deploy_error",
          level: "error",
          component: "GitDeployService",
          provider: deploy_provider,
          error_message: e.message,
          backtrace: e.backtrace.first(10).join("\n")
        log_activity(:error, "#{provider_name} 推送失败: #{e.message}")
        failure("推送到 #{provider_name} 失败: #{e.message}")
      ensure
        cleanup_deploy_directory
      end
    end

    def deploy_configured?
      return false if @settings.deploy_provider.blank? || @settings.deploy_provider == "local"
      return false if @settings.deploy_repo_url.blank?

      git_integration&.configured?
    end

    private

    def deploy_provider
      @settings.deploy_provider
    end

    def provider_name
      GitIntegration::PROVIDER_NAMES[deploy_provider] || deploy_provider&.titleize || "Git"
    end

    def git_integration
      @git_integration ||= GitIntegration.active_for_deploy(deploy_provider)
    end

    def branch
      @settings.deploy_branch.presence || "main"
    end

    def prepare_deploy_directory
      @deploy_dir = Pathname.new(Dir.mktmpdir("git_deploy-", Rails.root.join("tmp")))
    end

    def cleanup_deploy_directory
      return if @deploy_dir.blank?

      FileUtils.rm_rf(@deploy_dir)
    ensure
      @deploy_dir = nil
    end

    def clone_repository
      repo_url = git_integration.build_authenticated_url(@settings.deploy_repo_url)

      # Try clone with specified branch first
      output, status = git("clone", "--depth", "1", "--branch", branch, repo_url, @deploy_dir.to_s)

      unless status.success?
        # Branch might not exist, try default branch then create target branch
        FileUtils.rm_rf(@deploy_dir)
        output, status = git("clone", "--depth", "1", repo_url, @deploy_dir.to_s)
        raise "克隆仓库失败: #{mask_token(output)}" unless status.success?

        Dir.chdir(@deploy_dir) do
          output, status = git("checkout", "-b", branch)
          raise "创建分支失败: #{mask_token(output)}" unless status.success?
        end
      end

      # Configure git user
      Dir.chdir(@deploy_dir) do
        git("config", "user.email", "bot@versun.me")
        git("config", "user.name", "Rables Bot")
      end
    end

    def clear_repository_files
      Dir.chdir(@deploy_dir) do
        Dir.glob("*", File::FNM_DOTMATCH)
           .reject { |f| %w[. .. .git].include?(f) }
           .each { |entry| FileUtils.rm_rf(entry) }
      end
    end

    def copy_static_files
      # Git deploy mode always uses tmp/static_output directory
      source_dir = StaticGenerator::GITHUB_OUTPUT_DIR
      copied = 0

      StaticGenerator.deployable_items.each do |item|
        source = source_dir.join(item)
        next unless File.exist?(source)

        dest = @deploy_dir.join(item)
        File.directory?(source) ? FileUtils.cp_r(source, dest) : FileUtils.cp(source, dest)
        copied += 1
      end

      Rails.event.notify "git_deploy_service.files_copied",
        level: "info",
        component: "GitDeployService",
        provider: deploy_provider,
        copied_items: copied,
        source_dir: source_dir.to_s
    end

    def commit_and_push
      Dir.chdir(@deploy_dir) do
        git("add", "-A")

        # Skip if no changes
        output, = git("status", "--porcelain")
        if output.strip.empty?
          Rails.event.notify "git_deploy_service.no_changes",
            level: "info",
            component: "GitDeployService",
            provider: deploy_provider
          return
        end

        # Commit
        timestamp = Time.current.strftime("%Y-%m-%d %H:%M:%S")
        output, status = git("commit", "-m", "Deploy - #{timestamp}")
        raise "提交失败: #{mask_token(output)}" unless status.success?

        # Push (with force fallback for first push)
        repo_url = git_integration.build_authenticated_url(@settings.deploy_repo_url)
        output, status = git("push", repo_url, "HEAD:refs/heads/#{branch}")

        unless status.success?
          if output.include?("rejected") || output.include?("non-fast-forward")
            output, status = git("push", "--force-with-lease", repo_url, "HEAD:refs/heads/#{branch}")
          end
          raise "推送失败: #{mask_token(output)}" unless status.success?
        end

        Rails.event.notify "git_deploy_service.pushed",
          level: "info",
          component: "GitDeployService",
          provider: deploy_provider,
          branch: branch
      end
    end

    def git(*args)
      cmd_for_log = "git #{args.join(' ')}"
      Rails.event.notify "git_deploy_service.git_command",
        level: "debug",
        component: "GitDeployService",
        command: mask_token(cmd_for_log)
      env = { "GIT_TERMINAL_PROMPT" => "0" }
      output, status = Open3.capture2e(env, "git", *args)
      [ output, status ]
    end

    def mask_token(text)
      git_integration&.mask_token(text) || text
    end

    def log_activity(level, description)
      ActivityLog.create!(
        action: level == :error ? "failed" : "git_deploy",
        target: "git_deploy",
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
