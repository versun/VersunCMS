class GithubBackupService
  require "fileutils"
  require "reverse_markdown"

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

      # Export static files
      export_static_files

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

    # Export attachments and get URL mapping
    attachment_url_map = export_article_attachments(article)

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

    # Convert content to markdown
    markdown_content = ""
    if article.content.present?
      html_content = article.content.to_s
      markdown_content = html_to_markdown(html_content, attachment_url_map)
    end

    # Build markdown file
    content = "---\n"
    content += frontmatter.to_yaml.sub(/^---\n/, "")
    content += "---\n\n"
    content += markdown_content

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

    # Export attachments and get URL mapping
    attachment_url_map = export_page_attachments(page)

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

    # Convert content to markdown
    markdown_content = ""
    if page.content.present?
      html_content = page.content.to_s
      markdown_content = html_to_markdown(html_content, attachment_url_map)
    end

    # Build markdown file
    content = "---\n"
    content += frontmatter.to_yaml.sub(/^---\n/, "")
    content += "---\n\n"
    content += markdown_content

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

  # Convert ActionText HTML to Markdown
  def html_to_markdown(html_content, attachment_url_map = {})
    return "" if html_content.blank?

    # Replace Active Storage blob URLs with relative paths
    modified_html = html_content.dup
    attachment_url_map.each do |blob_url, relative_path|
      modified_html.gsub!(blob_url, relative_path)
    end

    # Convert to Markdown
    ReverseMarkdown.convert(modified_html, unknown_tags: :bypass, github_flavored: true)
  rescue => e
    Rails.logger.error "HTML to Markdown conversion failed: #{e.message}"
    # Fallback to plain HTML if conversion fails
    html_content
  end

  # Export article attachments and return URL mapping
  def export_article_attachments(article)
    return {} unless article.content.present?

    url_map = {}
    attachments_dir = File.join(@temp_dir, "attachments", "article_#{article.id}")

    begin
      # Get all attachments from ActionText content
      article.content.body.attachments.each do |attachment|
        next unless attachment.attachable.is_a?(ActiveStorage::Blob)

        blob = attachment.attachable
        next unless blob.persisted?

        # Create directory if needed
        FileUtils.mkdir_p(attachments_dir) unless Dir.exist?(attachments_dir)

        # Get original filename or generate one
        filename = blob.filename.to_s
        filepath = File.join(attachments_dir, filename)

        # Download and save the file
        File.open(filepath, "wb") do |file|
          blob.download { |chunk| file.write(chunk) }
        end

        # Store URL mapping for later replacement
        # Map blob URL to relative path from articles/ directory
        blob_url = Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: true)
        relative_path = "../attachments/article_#{article.id}/#{filename}"
        url_map[blob_url] = relative_path

        Rails.logger.info "Exported attachment: #{filename} for article #{article.id}"
      end

      # Also extract images from HTML content (img tags)
      html_content = article.content.to_s
      extract_images_from_html(html_content, attachments_dir, url_map, "article_#{article.id}")
    rescue => e
      Rails.logger.error "Failed to export attachments for article #{article.id}: #{e.message}"
    end

    url_map
  end

  # Export page attachments and return URL mapping
  def export_page_attachments(page)
    return {} unless page.content.present?

    url_map = {}
    attachments_dir = File.join(@temp_dir, "attachments", "page_#{page.id}")

    begin
      # Get all attachments from ActionText content
      page.content.body.attachments.each do |attachment|
        next unless attachment.attachable.is_a?(ActiveStorage::Blob)

        blob = attachment.attachable
        next unless blob.persisted?

        # Create directory if needed
        FileUtils.mkdir_p(attachments_dir) unless Dir.exist?(attachments_dir)

        # Get original filename
        filename = blob.filename.to_s
        filepath = File.join(attachments_dir, filename)

        # Download and save the file
        File.open(filepath, "wb") do |file|
          blob.download { |chunk| file.write(chunk) }
        end

        # Store URL mapping
        blob_url = Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: true)
        relative_path = "../attachments/page_#{page.id}/#{filename}"
        url_map[blob_url] = relative_path

        Rails.logger.info "Exported attachment: #{filename} for page #{page.id}"
      end

      # Also extract images from HTML content (img tags)
      html_content = page.content.to_s
      extract_images_from_html(html_content, attachments_dir, url_map, "page_#{page.id}")
    rescue => e
      Rails.logger.error "Failed to export attachments for page #{page.id}: #{e.message}"
    end

    url_map
  end

  # Export static files
  def export_static_files
    Rails.logger.info "Exporting static files..."

    static_dir = File.join(@temp_dir, "static_files")
    FileUtils.mkdir_p(static_dir)

    static_files_metadata = []

    StaticFile.find_each do |static_file|
      next unless static_file.file.attached?

      begin
        blob = static_file.file.blob
        filename = static_file.filename || blob.filename.to_s
        filepath = File.join(static_dir, filename)

        # Download and save the file
        File.open(filepath, "wb") do |file|
          blob.download { |chunk| file.write(chunk) }
        end

        # Collect metadata
        static_files_metadata << {
          filename: filename,
          content_type: blob.content_type,
          byte_size: blob.byte_size,
          created_at: static_file.created_at.iso8601
        }

        Rails.logger.info "Exported static file: #{filename}"
      rescue => e
        Rails.logger.error "Failed to export static file #{static_file.id}: #{e.message}"
      end
    end

    # Create index file
    index_filepath = File.join(static_dir, "index.json")
    File.write(index_filepath, JSON.pretty_generate(static_files_metadata))

    Rails.logger.info "Exported #{static_files_metadata.count} static files"
  end

  # Extract images from HTML content and add them to the backup
  def extract_images_from_html(html_content, attachments_dir, url_map, prefix)
    return if html_content.blank?

    require "nokogiri"
    doc = Nokogiri::HTML::DocumentFragment.parse(html_content)

    # Track which blob IDs have been processed to handle filename conflicts
    processed_blobs = {} # blob_id => filename mapping

    # Find all img tags
    doc.css("img").each do |img|
      src = img["src"]
      next if src.blank?

      # Check if it's an Active Storage blob URL
      if is_active_storage_url?(src)
        blob = extract_blob_from_url(src)
        next unless blob&.persisted?

        # Create directory if needed
        FileUtils.mkdir_p(attachments_dir) unless Dir.exist?(attachments_dir)

        # Get original filename
        original_filename = blob.filename.to_s

        # Check if this blob was already processed
        if processed_blobs[blob.id]
          # Use the filename we already assigned to this blob
          filename = processed_blobs[blob.id]
          filepath = File.join(attachments_dir, filename)
        else
          # Determine unique filename
          filename = original_filename
          filepath = File.join(attachments_dir, filename)

          # Check for filename conflicts
          # If file exists or another blob already uses this filename, use blob_id prefix
          if File.exist?(filepath) || processed_blobs.values.include?(filename)
            # Filename conflict detected, use blob_id prefix to ensure uniqueness
            ext = File.extname(original_filename)
            base_name = File.basename(original_filename, ext)
            filename = "#{blob.id}-#{base_name}#{ext}"
            filepath = File.join(attachments_dir, filename)
            Rails.logger.info "Filename conflict detected for #{original_filename}, using #{filename} for blob #{blob.id}"
          end

          # Download and save the file
          unless File.exist?(filepath)
            begin
              File.open(filepath, "wb") do |file|
                blob.download { |chunk| file.write(chunk) }
              end
              Rails.logger.info "Exported image from HTML: #{filename} for #{prefix} (blob #{blob.id})"
            rescue => e
              Rails.logger.error "Failed to export image #{filename} for #{prefix}: #{e.message}"
              next
            end
          end

          # Track this blob as processed
          processed_blobs[blob.id] = filename
        end

        # Store URL mapping
        # Handle both full URLs and relative paths
        blob_url = src.start_with?("http") ? src : Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: true)
        relative_path = "../attachments/#{prefix}/#{filename}"
        url_map[blob_url] = relative_path
        # Also map the relative path version
        url_map[src] = relative_path unless src == blob_url
      end
    end
  rescue => e
    Rails.logger.error "Failed to extract images from HTML for #{prefix}: #{e.message}"
  end

  # Check if URL is an Active Storage URL
  def is_active_storage_url?(url)
    url.include?("/rails/active_storage/blobs/") || url.include?("/rails/active_storage/representations/")
  end

  # Extract blob from Active Storage URL
  def extract_blob_from_url(url)
    # Format: /rails/active_storage/blobs/redirect/:signed_id/*filename
    # or /rails/active_storage/representations/redirect/:signed_id/*filename
    match = url.match(/\/rails\/active_storage\/(?:blobs|representations)\/redirect\/([^\/]+)/)
    return nil unless match

    signed_id = match[1]
    begin
      blob = ActiveStorage::Blob.find_signed(signed_id)
      Rails.logger.info "Found blob for signed_id #{signed_id}: #{blob&.filename}"
      blob
    rescue => e
      Rails.logger.error "Failed to find blob for signed_id #{signed_id}: #{e.message}"
      nil
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
