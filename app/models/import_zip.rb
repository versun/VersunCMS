class ImportZip
  require "csv"
  require "fileutils"
  require "zip"
  require "nokogiri"
  require "open-uri"
  require "securerandom"

  attr_reader :error_message, :import_dir, :zip_path

  def initialize(zip_path)
    @zip_path = zip_path
    @error_message = nil
    @import_dir = Rails.root.join("tmp", "imports", "import_#{Time.current.strftime('%Y%m%d_%H%M%S')}")
    FileUtils.mkdir_p(@import_dir)
  end

  def import_data
    ActivityLog.create!(
      action: "initiated",
      target: "zip_import",
      level: :info,
      description: "Start ZIP import from: #{@zip_path}"
    )
    extract_zip_file
    import_articles
    import_crossposts
    import_listmonks
    import_pages
    import_settings
    import_social_media_posts

    ActivityLog.create!(
      action: "completed",
      target: "zip_import",
      level: :info,
      description: "ZIP import completed successfully from: #{@zip_path}"
    )
    true
  rescue StandardError => e
    @error_message = e.message
    ActivityLog.create!(
      action: "failed",
      target: "zip_import",
      level: :error,
      description: "ZIP import failed from: #{@zip_path}, error: #{e.message}"
    )
    false
  ensure
    FileUtils.rm_rf(@import_dir) if @import_dir && File.directory?(@import_dir)
  end

  def error_message
    @error_message
  end

  private

  def extract_zip_file
    Rails.logger.info "Extracting ZIP file: #{@zip_path}"
    Zip::File.open(@zip_path) do |zip_file|
      zip_file.each do |entry|
        next if entry.directory?
        extract_path = File.join(@import_dir.to_s, entry.name)
        FileUtils.mkdir_p(File.dirname(extract_path))
        begin
          File.open(extract_path, "wb") { |f| f.write(entry.get_input_stream.read) }
          Rails.logger.info "Extracted: #{entry.name} -> #{extract_path}"
        rescue => e
          Rails.logger.error "Failed to extract #{entry.name}: #{e.message}"
          raise
        end
      end
    end
    Rails.logger.info "ZIP file extracted to: #{@import_dir}"
  end

  # Find the directory containing CSV files
  # This handles cases where ZIP files have a subdirectory wrapper
  def find_csv_base_dir
    # First check if CSV files are in the root import directory
    return @import_dir if Dir.glob(File.join(@import_dir, "*.csv")).any?
    
    # Otherwise, search for the first subdirectory containing CSV files
    Dir.glob(File.join(@import_dir, "*", "*.csv")).first&.then { |path| File.dirname(path) } || @import_dir
  end

  def import_articles
    base_dir = find_csv_base_dir
    csv_path = File.join(base_dir, "articles.csv")
    return unless File.exist?(csv_path)

    Rails.logger.info "Importing articles from: #{csv_path}"
    imported_count = 0
    skipped_count = 0
    CSV.foreach(csv_path, headers: true) do |row|
      if Article.exists?(slug: row["slug"])
        Rails.logger.info "Article with slug '#{row['slug']}' already exists, skipping..."
        skipped_count += 1
        next
      end
      article_id = row["id"].presence || "article_#{imported_count + skipped_count}"
      content = row["content"].presence || ""
      processed_content = process_imported_content(content, article_id, "article")
      processed_content = fix_content_sgid_references(processed_content)
      Article.create!(
        title: row["title"],
        slug: row["slug"],
        description: row["description"],
        content: processed_content,
        status: row["status"],
        scheduled_at: row["scheduled_at"],
        crosspost_mastodon: row["crosspost_mastodon"],
        crosspost_twitter: row["crosspost_twitter"],
        crosspost_bluesky: row["crosspost_bluesky"],
        send_newsletter: row["send_newsletter"],
        created_at: row["created_at"],
        updated_at: row["updated_at"]
      )
      imported_count += 1
    end
    Rails.logger.info "Articles import completed: #{imported_count} imported, #{skipped_count} skipped"
  end

  def import_crossposts
    base_dir = find_csv_base_dir
    csv_path = File.join(base_dir, "crossposts.csv")
    return unless File.exist?(csv_path)

    Rails.logger.info "Importing crossposts from: #{csv_path}"
    imported_count = 0
    CSV.foreach(csv_path, headers: true) do |row|
      Crosspost.update(
        platform: row["platform"],
        server_url: row["server_url"],
        client_key: row["client_key"],
        client_secret: row["client_secret"],
        access_token: row["access_token"],
        access_token_secret: row["access_token_secret"],
        api_key: row["api_key"],
        api_key_secret: row["api_key_secret"],
        username: row["username"],
        app_password: row["app_password"],
        enabled: row["enabled"],
        created_at: row["created_at"],
        updated_at: row["updated_at"]
      )
      imported_count += 1
    end
    Rails.logger.info "Crossposts import completed: #{imported_count} imported"
  end

  def import_listmonks
    base_dir = find_csv_base_dir
    csv_path = File.join(base_dir, "listmonks.csv")
    return unless File.exist?(csv_path)
    Rails.logger.info "Importing listmonks from: #{csv_path}"
    imported_count = 0
    CSV.foreach(csv_path, headers: true) do |row|
      Listmonk.find_or_create_by(
        url: row["url"],
        username: row["username"],
        api_key: row["api_key"],
        list_id: row["list_id"],
        template_id: row["template_id"],
        enabled: row["enabled"],
        created_at: row["created_at"],
        updated_at: row["updated_at"]
      )
      imported_count += 1
    end
    Rails.logger.info "Listmonks import completed: #{imported_count} imported"
  end

  def import_pages
    base_dir = find_csv_base_dir
    csv_path = File.join(base_dir, "pages.csv")
    return unless File.exist?(csv_path)
    Rails.logger.info "Importing pages from: #{csv_path}"
    imported_count = 0
    skipped_count = 0
    CSV.foreach(csv_path, headers: true) do |row|
      if Page.exists?(slug: row["slug"])
        Rails.logger.info "Page with slug '#{row['slug']}' already exists, skipping..."
        skipped_count += 1
        next
      end
      page_id = row["id"].presence || "page_#{imported_count + skipped_count}"
      content = row["content"].presence || ""
      processed_content = process_imported_content(content, page_id, "page")
      processed_content = fix_content_sgid_references(processed_content)
      Page.create!(
        title: row["title"],
        slug: row["slug"],
        content: processed_content,
        status: row["status"],
        redirect_url: row["redirect_url"],
        page_order: row["page_order"],
        created_at: row["created_at"],
        updated_at: row["updated_at"]
      )
      imported_count += 1
    end
    Rails.logger.info "Pages import completed: #{imported_count} imported, #{skipped_count} skipped"
  end

  def import_settings
    base_dir = find_csv_base_dir
    csv_path = File.join(base_dir, "settings.csv")
    return unless File.exist?(csv_path)
    Rails.logger.info "Importing settings from: #{csv_path}"
    imported_count = 0
    # 只允许有一个 Setting
    existing_setting = Setting.first
    if existing_setting
      csv_data = CSV.read(csv_path, headers: true).first
      return unless csv_data
      social_links = parse_json_field(csv_data["social_links"])
      static_files = parse_json_field(csv_data["static_files"])
      existing_setting.update!(
        title: csv_data["title"],
        description: csv_data["description"],
        author: csv_data["author"],
        url: csv_data["url"],
        time_zone: csv_data["time_zone"] || "UTC",
        giscus: csv_data["giscus"],
        tool_code: csv_data["tool_code"],
        head_code: csv_data["head_code"],
        custom_css: csv_data["custom_css"],
        social_links: social_links,
        static_files: static_files || {},
        created_at: csv_data["created_at"],
        updated_at: csv_data["updated_at"]
      )
      imported_count += 1
    else
      CSV.foreach(csv_path, headers: true) do |row|
        social_links = parse_json_field(row["social_links"])
        static_files = parse_json_field(row["static_files"])
        Setting.create!(
          title: row["title"],
          description: row["description"],
          author: row["author"],
          url: row["url"],
          time_zone: row["time_zone"] || "UTC",
          giscus: row["giscus"],
          tool_code: row["tool_code"],
          head_code: row["head_code"],
          custom_css: row["custom_css"],
          social_links: social_links,
          static_files: static_files || {},
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        )
        imported_count += 1
      end
    end
    # 富文本 footer
    footer_csv_path = File.join(base_dir, "setting_footers.csv")
    if File.exist?(footer_csv_path)
      Rails.logger.info "Importing setting footer content..."
      CSV.foreach(footer_csv_path, headers: true) do |row|
        setting = Setting.first
        content = row["content"].presence || ""
        if setting && content.present?
          processed_content = process_setting_footer_content(content, setting.id, "setting")
          processed_content = fix_content_sgid_references(processed_content)
          setting.update!(footer: processed_content)
          Rails.logger.info "Updated setting footer content"
        end
      end
    end
    Rails.logger.info "Settings import completed: #{imported_count} imported"
  rescue StandardError => e
    Rails.logger.error "Error importing settings: #{e.message}"
    raise
  end

  def import_social_media_posts
    base_dir = find_csv_base_dir
    csv_path = File.join(base_dir, "social_media_posts.csv")
    return unless File.exist?(csv_path)

    Rails.logger.info "Importing social_media_posts from: #{csv_path}"
    imported_count = 0
    skipped_count = 0
    CSV.foreach(csv_path, headers: true) do |row|
      # 检查关联的 article 是否存在
      article_id = row["article_id"]
      unless Article.exists?(id: article_id)
        Rails.logger.info "Article with id '#{article_id}' does not exist, skipping social_media_post..."
        skipped_count += 1
        next
      end

      # 检查是否已存在相同的记录（根据 article_id 和 platform）
      if SocialMediaPost.exists?(article_id: article_id, platform: row["platform"])
        Rails.logger.info "SocialMediaPost for article_id '#{article_id}' and platform '#{row['platform']}' already exists, skipping..."
        skipped_count += 1
        next
      end

      SocialMediaPost.create!(
        article_id: article_id,
        platform: row["platform"],
        url: row["url"],
        created_at: row["created_at"],
        updated_at: row["updated_at"]
      )
      imported_count += 1
    end
    Rails.logger.info "Social_media_posts import completed: #{imported_count} imported, #{skipped_count} skipped"
  end

  # ----- 内容和附件处理通用工具方法 -----
  def process_imported_content(content, record_id = nil, record_type = nil)
    return content if content.blank?
    record_id ||= "unknown"
    record_type ||= "content"
    Rails.logger.info "process_imported_content called with record_id: #{record_id}, record_type: #{record_type}"
    doc = Nokogiri::HTML.fragment(content)

    doc.css("action-text-attachment").each { |a| safe_process { process_imported_attachment_element(a, record_id, record_type) } }
    doc.css("figure[data-trix-attachment]").each { |f| safe_process { process_imported_figure_element(f, record_id, record_type) } }
    doc.css("img").each { |img| safe_process { process_imported_image_element(img, record_id, record_type) } }

    doc.to_html
  end

  def process_imported_attachment_element(attachment, record_id = nil, record_type = nil)
    record_id ||= "unknown"
    record_type ||= "attachment"
    return unless attachment.respond_to?(:[])
    content_type = attachment["content-type"]
    original_url = attachment["url"]
    filename = attachment["filename"]
    return unless original_url.present? && filename.present?

    if is_local_attachment?(original_url)
      attachment_path = safe_join_path(@import_dir, original_url)
      if File.exist?(attachment_path) && safe_file_path?(attachment_path)
        File.open(attachment_path) do |file|
          content_type ||= "application/octet-stream"
          blob = ActiveStorage::Blob.create_and_upload!(
            io: file, filename: filename, content_type: content_type
          )
          update_attachment_element_with_blob(attachment, blob)
        end
      else
        Rails.logger.warn "Attachment file not found: #{attachment_path}"
      end
    elsif is_active_storage_url?(original_url)
      blob = extract_blob_from_url(original_url)
      update_attachment_element_with_blob(attachment, blob) if blob
    end
  end

  def process_imported_figure_element(figure, record_id = nil, record_type = nil)
    record_id ||= "unknown"
    record_type ||= "figure"
    return unless figure.respond_to?(:[])
    attachment_data = JSON.parse(figure["data-trix-attachment"]) rescue nil
    return unless attachment_data
    original_url = attachment_data["url"]
    filename = attachment_data["filename"] || File.basename(original_url) if original_url.present?
    content_type = attachment_data["contentType"]
    return unless original_url.present? && filename.present?

    if is_local_attachment?(original_url)
      attachment_path = safe_join_path(@import_dir, original_url)
      if File.exist?(attachment_path) && safe_file_path?(attachment_path)
        File.open(attachment_path) do |file|
          content_type ||= "application/octet-stream"
          blob = ActiveStorage::Blob.create_and_upload!(
            io: file, filename: filename, content_type: content_type
          )
          attachment_data["url"] = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
          figure["sgid"] = blob.to_sgid.to_s
          figure["data-trix-attachment"] = attachment_data.to_json
          update_img_src_in_node(figure, attachment_data["url"])
        end
      else
        Rails.logger.warn "Figure attachment file not found: #{attachment_path}"
      end
    elsif is_active_storage_url?(original_url)
      blob = extract_blob_from_url(original_url)
      if blob
        attachment_data["url"] = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
        figure["sgid"] = blob.to_sgid.to_s
        figure["data-trix-attachment"] = attachment_data.to_json
        update_img_src_in_node(figure, attachment_data["url"])
      end
    end
  end

  def process_imported_image_element(img, record_id = nil, record_type = nil)
    record_id ||= "unknown"
    record_type ||= "image"
    return unless img.respond_to?(:[])
    original_url = img["src"]
    return unless original_url.present?

    if is_local_attachment?(original_url)
      attachment_path = safe_join_path(@import_dir, original_url)
      if File.exist?(attachment_path) && safe_file_path?(attachment_path)
        File.open(attachment_path) do |file|
          filename = File.basename(attachment_path)
          content_type = detect_content_type(attachment_path)
          blob = ActiveStorage::Blob.create_and_upload!(
            io: file, filename: filename, content_type: content_type
          )
          # img['src'] = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
          signed_id = blob.signed_id
          filename = blob.filename.to_s
          new_url = Rails.application.routes.url_helpers.rails_blob_path(signed_id: signed_id, filename: filename, only_path: true)
          img["src"] = new_url
        end
      else
        Rails.logger.warn "Image file not found: #{attachment_path}"
      end
    elsif is_active_storage_url?(original_url)
      blob = extract_blob_from_url(original_url)
      # img['src'] = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true) if blob
      signed_id = blob.signed_id
      filename = blob.filename.to_s
      new_url = Rails.application.routes.url_helpers.rails_blob_path(signed_id: signed_id, filename: filename, only_path: true)
      img["src"] = new_url
    end
  end

  def process_setting_footer_content(content, record_id = nil, record_type = nil)
    return content if content.blank?
    record_id ||= "setting"
    record_type ||= "setting"
    Rails.logger.info "process_setting_footer_content..."
    doc = Nokogiri::HTML.fragment(content)
    doc.css("action-text-attachment").each { |a| safe_process { process_imported_attachment_element(a, record_id, record_type) } }
    doc.css("figure[data-trix-attachment]").each { |f| safe_process { process_imported_figure_element(f, record_id, record_type) } }
    doc.css("img").each { |img| safe_process { process_imported_image_element(img, record_id, record_type) } }
    doc.to_html
  end

  def fix_content_sgid_references(content)
    return content unless content.present?
    doc = Nokogiri::HTML(content)
    doc.css("action-text-attachment").each do |attachment|
      begin
        filename = attachment["filename"]
        next unless filename.present?
        blob = ActiveStorage::Blob.find_by(filename: filename)
        next unless blob
        current_sgid = attachment["sgid"]
        correct_sgid = blob.to_sgid.to_s
        attachment["sgid"] = correct_sgid if current_sgid != correct_sgid
        if blob && blob.filename.present?
          correct_signed_id = blob.signed_id
          correct_url = Rails.application.routes.url_helpers.rails_blob_path(
            signed_id: blob.signed_id,
            filename: blob.filename.to_s,
            only_path: true
          )
          attachment["url"] = correct_url
        end
      rescue => e
        Rails.logger.error "Error fixing attachment in content: #{e.message}"
      end
    end

    doc.css("figure[data-trix-attachment]").each do |figure|
      begin
        attachment_data = JSON.parse(figure["data-trix-attachment"]) rescue nil
        next unless attachment_data
        filename = attachment_data["filename"]
        next unless filename.present?
        blob = ActiveStorage::Blob.find_by(filename: filename)
        next unless blob
        current_sgid = figure["sgid"]
        correct_sgid = blob.to_sgid.to_s
        figure["sgid"] = correct_sgid if current_sgid != correct_sgid
      rescue => e
        Rails.logger.error "Error fixing figure in content: #{e.message}"
      end
    end

    doc.to_html
  rescue => e
    Rails.logger.error "Error fixing content SGID references: #{e.message}"
    content # 返回原始内容, 如果异常
  end

  # 工具&校验方法
  def parse_json_field(json_string)
    return nil if json_string.blank?
    JSON.parse(json_string)
  rescue JSON::ParserError
    Rails.logger.warn "Invalid JSON format, using empty hash"
    {}
  end

  def detect_content_type(file_path)
    mime_type = `file --brief --mime-type #{file_path.shellescape}`.strip rescue nil
    mime_type.present? && !mime_type.include?("error") ? mime_type : "application/octet-stream"
  end

  def extract_blob_from_url(url)
    match = url.match(/\/rails\/active_storage\/(?:blobs|representations)\/redirect\/([^\/]+)/)
    return nil unless match
    signed_id = match[1]
    ActiveStorage::Blob.find_signed(signed_id)
  rescue => e
    Rails.logger.error "Failed to find blob for signed_id #{signed_id}: #{e.message}"
    nil
  end

  def safe_join_path(base_path, relative_path)
    clean_path = relative_path.to_s.gsub(/\.{2,}/, "").gsub(%r{^/}, "")
    # Use find_csv_base_dir if base_path is @import_dir
    actual_base = (base_path == @import_dir) ? find_csv_base_dir : base_path
    File.join(actual_base, clean_path)
  end

  def safe_file_path?(file_path)
    expanded_path = File.expand_path(file_path)
    expanded_import_dir = File.expand_path(@import_dir)
    expanded_path.start_with?(expanded_import_dir)
  end

  def update_attachment_element_with_blob(attachment, blob)
    url = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
    attachment["url"] = url
    attachment["sgid"] = blob.to_sgid.to_s
    update_img_src_in_node(attachment, url)
  end

  def update_img_src_in_node(node, url)
    img = node.at_css("img")
    img["src"] = url if img
  end

  def is_local_attachment?(url)
    url.include?("attachments/") && !url.start_with?("http")
  end

  def is_active_storage_url?(url)
    url.include?("/rails/active_storage/blobs/") || url.include?("/rails/active_storage/representations/")
  end

  def safe_process
    yield
  rescue => e
    Rails.logger.error "Safe process exception: #{e.message}"
  end
end
