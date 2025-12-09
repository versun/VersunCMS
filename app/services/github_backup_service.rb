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

      # Export other data to JSON/CSV
      export_tags
      export_comments
      export_redirects
      export_settings
      export_crossposts
      export_listmonks
      export_newsletter_settings
      export_subscribers
      export_social_media_posts
      export_article_tags
      export_subscriber_tags

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

    # Add tags
    if article.tags.any?
      frontmatter["tags"] = article.tags.map(&:slug)
    end

    # Convert content to markdown
    markdown_content = ""
    if article.html?
      html_content = article.html_content || ""
      markdown_content = html_to_markdown(html_content, attachment_url_map)
    elsif article.content.present?
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
    # 对于 HTML 类型，只处理 HTML 中的图片；对于富文本类型，处理 ActionText 附件
    return {} if article.html? && article.html_content.blank?
    return {} if article.rich_text? && article.content.blank?

    url_map = {}
    attachments_dir = File.join(@temp_dir, "attachments", "article_#{article.id}")

    begin
      # Get all attachments from ActionText content (only for rich_text type)
      if article.rich_text? && article.content.present?
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
      end

      # Also extract images from HTML content (img tags)
      html_content = article.html? ? (article.html_content || "") : (article.content.present? ? article.content.to_s : "")
      extract_images_from_html(html_content, attachments_dir, url_map, "article_#{article.id}") if html_content.present?
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

  def export_tags
    Rails.logger.info "Exporting tags..."

    tags_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(tags_dir)

    tags_data = []
    Tag.order(:id).find_each do |tag|
      tags_data << {
        id: tag.id,
        name: tag.name,
        slug: tag.slug,
        created_at: tag.created_at.iso8601,
        updated_at: tag.updated_at.iso8601
      }
    end

    tags_filepath = File.join(tags_dir, "tags.json")
    File.write(tags_filepath, JSON.pretty_generate(tags_data))

    Rails.logger.info "Exported #{tags_data.count} tags"
  end

  def export_comments
    Rails.logger.info "Exporting comments..."

    comments_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(comments_dir)

    comments_data = []
    Comment.order(:id).find_each do |comment|
      comments_data << {
        id: comment.id,
        article_id: comment.article_id,
        article_slug: comment.article&.slug,
        parent_id: comment.parent_id,
        author_name: comment.author_name,
        author_url: comment.author_url,
        author_username: comment.author_username,
        author_avatar_url: comment.author_avatar_url,
        content: comment.content,
        platform: comment.platform,
        external_id: comment.external_id,
        status: comment.status,
        published_at: comment.published_at&.iso8601,
        url: comment.url,
        created_at: comment.created_at.iso8601,
        updated_at: comment.updated_at.iso8601
      }
    end

    comments_filepath = File.join(comments_dir, "comments.json")
    File.write(comments_filepath, JSON.pretty_generate(comments_data))

    Rails.logger.info "Exported #{comments_data.count} comments"
  end

  def export_redirects
    Rails.logger.info "Exporting redirects..."

    data_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(data_dir)

    redirects_data = []
    Redirect.order(:id).find_each do |redirect|
      redirects_data << {
        id: redirect.id,
        regex: redirect.regex,
        replacement: redirect.replacement,
        enabled: redirect.enabled,
        permanent: redirect.permanent,
        created_at: redirect.created_at.iso8601,
        updated_at: redirect.updated_at.iso8601
      }
    end

    redirects_filepath = File.join(data_dir, "redirects.json")
    File.write(redirects_filepath, JSON.pretty_generate(redirects_data))

    Rails.logger.info "Exported #{redirects_data.count} redirects"
  end

  def export_settings
    Rails.logger.info "Exporting settings..."

    data_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(data_dir)

    settings_data = []
    Setting.order(:id).find_each do |setting|
      # Export footer content as HTML
      footer_html = setting.footer.present? ? setting.footer.to_s : nil

      settings_data << {
        id: setting.id,
        title: setting.title,
        description: setting.description,
        author: setting.author,
        url: setting.url,
        time_zone: setting.time_zone,
        head_code: setting.head_code,
        custom_css: setting.custom_css,
        social_links: setting.social_links,
        static_files: setting.static_files,
        tool_code: setting.tool_code,
        giscus: setting.giscus,
        footer: footer_html,
        github_backup_enabled: setting.github_backup_enabled,
        github_repo_url: setting.github_repo_url,
        github_backup_branch: setting.github_backup_branch,
        git_user_name: setting.git_user_name,
        git_user_email: setting.git_user_email,
        created_at: setting.created_at.iso8601,
        updated_at: setting.updated_at.iso8601
      }
    end

    settings_filepath = File.join(data_dir, "settings.json")
    File.write(settings_filepath, JSON.pretty_generate(settings_data))

    Rails.logger.info "Exported #{settings_data.count} settings"
  end

  def export_crossposts
    Rails.logger.info "Exporting crossposts..."

    data_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(data_dir)

    crossposts_data = []
    Crosspost.order(:id).find_each do |crosspost|
      crossposts_data << {
        id: crosspost.id,
        platform: crosspost.platform,
        server_url: crosspost.server_url,
        client_key: crosspost.client_key,
        client_secret: crosspost.client_secret,
        access_token: crosspost.access_token,
        access_token_secret: crosspost.access_token_secret,
        api_key: crosspost.api_key,
        api_key_secret: crosspost.api_key_secret,
        username: crosspost.username,
        app_password: crosspost.app_password,
        enabled: crosspost.enabled,
        auto_fetch_comments: crosspost.auto_fetch_comments,
        comment_fetch_schedule: crosspost.comment_fetch_schedule,
        settings: crosspost.settings,
        created_at: crosspost.created_at.iso8601,
        updated_at: crosspost.updated_at.iso8601
      }
    end

    crossposts_filepath = File.join(data_dir, "crossposts.json")
    File.write(crossposts_filepath, JSON.pretty_generate(crossposts_data))

    Rails.logger.info "Exported #{crossposts_data.count} crossposts"
  end

  def export_newsletter_settings
    Rails.logger.info "Exporting newsletter_settings..."

    data_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(data_dir)

    newsletter_settings_data = []
    NewsletterSetting.order(:id).find_each do |setting|
      # Export footer content as HTML
      footer_html = setting.footer.present? ? setting.footer.to_s : nil

      newsletter_settings_data << {
        id: setting.id,
        provider: setting.provider,
        enabled: setting.enabled,
        smtp_address: setting.smtp_address,
        smtp_port: setting.smtp_port,
        smtp_user_name: setting.smtp_user_name,
        smtp_password: setting.smtp_password,
        smtp_domain: setting.smtp_domain,
        smtp_authentication: setting.smtp_authentication,
        smtp_enable_starttls: setting.smtp_enable_starttls,
        from_email: setting.from_email,
        footer: footer_html,
        created_at: setting.created_at.iso8601,
        updated_at: setting.updated_at.iso8601
      }
    end

    newsletter_settings_filepath = File.join(data_dir, "newsletter_settings.json")
    File.write(newsletter_settings_filepath, JSON.pretty_generate(newsletter_settings_data))

    Rails.logger.info "Exported #{newsletter_settings_data.count} newsletter_settings"
  end

  def export_subscribers
    Rails.logger.info "Exporting subscribers..."

    data_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(data_dir)

    subscribers_data = []
    Subscriber.order(:id).find_each do |subscriber|
      subscribers_data << {
        id: subscriber.id,
        email: subscriber.email,
        confirmation_token: subscriber.confirmation_token,
        confirmed_at: subscriber.confirmed_at&.iso8601,
        unsubscribe_token: subscriber.unsubscribe_token,
        unsubscribed_at: subscriber.unsubscribed_at&.iso8601,
        created_at: subscriber.created_at.iso8601,
        updated_at: subscriber.updated_at.iso8601
      }
    end

    subscribers_filepath = File.join(data_dir, "subscribers.json")
    File.write(subscribers_filepath, JSON.pretty_generate(subscribers_data))

    Rails.logger.info "Exported #{subscribers_data.count} subscribers"
  end

  def export_article_tags
    Rails.logger.info "Exporting article_tags..."

    data_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(data_dir)

    article_tags_data = []
    ArticleTag.order(:id).find_each do |article_tag|
      article_tags_data << {
        id: article_tag.id,
        article_id: article_tag.article_id,
        article_slug: article_tag.article&.slug,
        tag_id: article_tag.tag_id,
        tag_name: article_tag.tag&.name,
        tag_slug: article_tag.tag&.slug,
        created_at: article_tag.created_at.iso8601,
        updated_at: article_tag.updated_at.iso8601
      }
    end

    article_tags_filepath = File.join(data_dir, "article_tags.json")
    File.write(article_tags_filepath, JSON.pretty_generate(article_tags_data))

    Rails.logger.info "Exported #{article_tags_data.count} article_tags"
  end

  def export_subscriber_tags
    Rails.logger.info "Exporting subscriber_tags..."

    data_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(data_dir)

    subscriber_tags_data = []
    SubscriberTag.order(:id).find_each do |subscriber_tag|
      subscriber_tags_data << {
        id: subscriber_tag.id,
        subscriber_id: subscriber_tag.subscriber_id,
        subscriber_email: subscriber_tag.subscriber&.email,
        tag_id: subscriber_tag.tag_id,
        tag_name: subscriber_tag.tag&.name,
        tag_slug: subscriber_tag.tag&.slug,
        created_at: subscriber_tag.created_at.iso8601,
        updated_at: subscriber_tag.updated_at.iso8601
      }
    end

    subscriber_tags_filepath = File.join(data_dir, "subscriber_tags.json")
    File.write(subscriber_tags_filepath, JSON.pretty_generate(subscriber_tags_data))

    Rails.logger.info "Exported #{subscriber_tags_data.count} subscriber_tags"
  end

  def export_listmonks
    Rails.logger.info "Exporting listmonks..."

    data_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(data_dir)

    listmonks_data = []
    Listmonk.order(:id).find_each do |listmonk|
      listmonks_data << {
        id: listmonk.id,
        url: listmonk.url,
        username: listmonk.username,
        api_key: listmonk.api_key,
        list_id: listmonk.list_id,
        template_id: listmonk.template_id,
        enabled: listmonk.enabled,
        created_at: listmonk.created_at.iso8601,
        updated_at: listmonk.updated_at.iso8601
      }
    end

    listmonks_filepath = File.join(data_dir, "listmonks.json")
    File.write(listmonks_filepath, JSON.pretty_generate(listmonks_data))

    Rails.logger.info "Exported #{listmonks_data.count} listmonks"
  end

  def export_social_media_posts
    Rails.logger.info "Exporting social_media_posts..."

    data_dir = File.join(@temp_dir, "data")
    FileUtils.mkdir_p(data_dir)

    social_media_posts_data = []
    SocialMediaPost.order(:id).find_each do |post|
      social_media_posts_data << {
        id: post.id,
        article_id: post.article_id,
        article_slug: post.article&.slug,
        platform: post.platform,
        url: post.url,
        created_at: post.created_at.iso8601,
        updated_at: post.updated_at.iso8601
      }
    end

    social_media_posts_filepath = File.join(data_dir, "social_media_posts.json")
    File.write(social_media_posts_filepath, JSON.pretty_generate(social_media_posts_data))

    Rails.logger.info "Exported #{social_media_posts_data.count} social_media_posts"
  end

  def cleanup
    # Clean up temporary directory
    if @temp_dir && Dir.exist?(@temp_dir)
      FileUtils.rm_rf(@temp_dir)
      Rails.logger.info "Cleaned up temporary directory: #{@temp_dir}"
    end
  end
end
