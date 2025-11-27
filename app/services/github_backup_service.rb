class GithubBackupService
  require "fileutils"

  attr_reader :error_message

  def initialize
    @error_message = nil
    @setting = Setting.first
    @temp_dir = Rails.root.join("tmp", "github_backup_#{Time.current.to_i}")
  end

  def backup
    unless configured?
      @error_message = "GitHub backup is not configured or not enabled"
      Rails.logger.error @error_message
      return false
    end

    begin
      Rails.logger.info "Starting GitHub backup..."

      # Clone or pull the repository
      setup_repository

      # Export articles and pages to markdown
      export_articles
      export_pages

      # Commit and push changes
      commit_and_push

      Rails.logger.info "GitHub backup completed successfully!"
      true
    rescue => e
      @error_message = e.message
      Rails.logger.error "GitHub backup failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    ensure
      cleanup
    end
  end

  private

  def configured?
    @setting&.github_backup_enabled &&
      @setting.github_repo_url.present? &&
      @setting.github_token.present?
  end

  def setup_repository
    require "git"  # Only load git gem when actually needed
    
    Rails.logger.info "Setting up repository: #{@setting.github_repo_url}"

    # Create temp directory
    FileUtils.mkdir_p(@temp_dir)

    # Build authenticated URL
    repo_url = build_authenticated_url(@setting.github_repo_url, @setting.github_token)
    branch = @setting.github_backup_branch.presence || "main"

    begin
      # Try to clone the repository
      @git = Git.clone(repo_url, @temp_dir, branch: branch)
      Rails.logger.info "Repository cloned successfully"
    rescue Git::GitExecuteError => e
      # If clone fails, initialize a new repo
      Rails.logger.info "Clone failed, initializing new repository: #{e.message}"
      @git = Git.init(@temp_dir)
      @git.add_remote("origin", repo_url)
    end

    # Configure git user
    configure_git_user
  end

  def configure_git_user
    user_name = @setting.git_user_name.presence || "VersunCMS"
    user_email = @setting.git_user_email.presence || "backup@versuncms.local"

    @git.config("user.name", user_name)
    @git.config("user.email", user_email)

    Rails.logger.info "Git user configured: #{user_name} <#{user_email}>"
  end

  def build_authenticated_url(repo_url, token)
    # Convert SSH URLs to HTTPS if needed
    if repo_url.start_with?("git@github.com:")
      repo_url = repo_url.sub("git@github.com:", "https://github.com/")
      repo_url = repo_url.sub(/\.git$/, "")
    end

    # Insert token into HTTPS URL
    if repo_url.include?("github.com")
      repo_url.sub("https://", "https://#{token}@")
    else
      repo_url
    end
  end

  def export_articles
    Rails.logger.info "Exporting articles..."

    articles_dir = File.join(@temp_dir, "articles")
    FileUtils.mkdir_p(articles_dir)

    Article.published.order(created_at: :desc).each do |article|
      export_article_to_markdown(article, articles_dir)
    end

    Rails.logger.info "Exported #{Article.published.count} articles"
  end

  def export_article_to_markdown(article, dir)
    # Generate filename: YYYY-MM-DD-slug.md
    date_prefix = article.created_at.strftime("%Y-%m-%d")
    filename = "#{date_prefix}-#{article.slug}.md"
    filepath = File.join(dir, filename)

    # Build YAML frontmatter
    frontmatter = {
      "title" => article.title,
      "slug" => article.slug,
      "status" => article.status,
      "description" => article.description,
      "created_at" => article.created_at.iso8601,
      "updated_at" => article.updated_at.iso8601
    }

    if article.scheduled_at.present?
      frontmatter["scheduled_at"] = article.scheduled_at.iso8601
    end

    # Build markdown content
    content = "---\n"
    content += frontmatter.to_yaml.sub(/^---\n/, "")
    content += "---\n\n"
    content += article.content.to_plain_text if article.content.present?

    # Write to file
    File.write(filepath, content)
  end

  def export_pages
    Rails.logger.info "Exporting pages..."

    pages_dir = File.join(@temp_dir, "pages")
    FileUtils.mkdir_p(pages_dir)

    Page.published.order(:page_order).each do |page|
      export_page_to_markdown(page, pages_dir)
    end

    Rails.logger.info "Exported #{Page.published.count} pages"
  end

  def export_page_to_markdown(page, dir)
    # Generate filename: slug.md
    filename = "#{page.slug}.md"
    filepath = File.join(dir, filename)

    # Build YAML frontmatter
    frontmatter = {
      "title" => page.title,
      "slug" => page.slug,
      "status" => page.status,
      "page_order" => page.page_order,
      "created_at" => page.created_at.iso8601,
      "updated_at" => page.updated_at.iso8601
    }

    if page.redirect_url.present?
      frontmatter["redirect_url"] = page.redirect_url
    end

    # Build markdown content
    content = "---\n"
    content += frontmatter.to_yaml.sub(/^---\n/, "")
    content += "---\n\n"
    content += page.content.to_plain_text if page.content.present?

    # Write to file
    File.write(filepath, content)
  end

  def commit_and_push
    Rails.logger.info "Committing and pushing changes..."

    # Add all changes
    @git.add(all: true)

    # Check if there are changes to commit
    status = @git.status
    if status.changed.empty? && status.added.empty? && status.deleted.empty?
      Rails.logger.info "No changes to commit"
      return
    end

    # Commit with timestamp
    commit_message = "Backup at #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    @git.commit(commit_message)

    # Push to remote
    branch = @setting.github_backup_branch.presence || "main"
    begin
      @git.push("origin", branch)
      Rails.logger.info "Pushed to #{branch} branch successfully"
    rescue Git::GitExecuteError => e
      # If branch doesn't exist on remote, push with -u
      Rails.logger.info "Branch doesn't exist on remote, creating: #{e.message}"
      @git.push("origin", branch, set_upstream: true)
    end
  end

  def cleanup
    # Clean up temporary directory
    if @temp_dir && Dir.exist?(@temp_dir)
      FileUtils.rm_rf(@temp_dir)
      Rails.logger.info "Cleaned up temporary directory: #{@temp_dir}"
    end
  end
end
