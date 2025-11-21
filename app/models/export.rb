class Export
  require "csv"
  require "fileutils"
  require "nokogiri"
  require "open-uri"
  require "securerandom"
  require "zip"

  attr_reader :zip_path, :error_message, :export_dir, :attachments_dir

  def initialize
    @zip_path = nil
    @error_message = nil
    @export_dir = Rails.root.join("tmp", "exports", "export_#{Time.current.strftime('%Y%m%d_%H%M%S')}")
    @attachments_dir = File.join(@export_dir, "attachments")

    # 创建导出目录
    FileUtils.mkdir_p(@export_dir)
    FileUtils.mkdir_p(@attachments_dir)

    # 检查数据库连接
    check_database_connection
  end

  def check_database_connection
    begin
      # 尝试执行一个简单的查询来检查数据库连接
      ActiveRecord::Base.connection.execute("SELECT 1")
      true
    rescue => e
      @error_message = "Database connection failed: #{e.message}"
      Rails.logger.error @error_message
      false
    end
  end

  def generate
    begin
      Rails.logger.info "Starting data export to: #{@export_dir}"

      # export_activity_logs
      export_articles
      export_crossposts
      export_listmonks
      export_pages
      export_settings
      export_social_media_posts
      export_users

      # 创建ZIP文件
      create_zip_file

      Rails.logger.info "Export completed successfully!"
      true
    rescue => e
      @error_message = e.message
      Rails.logger.error "Export failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  private

  def export_activity_logs
    Rails.logger.info "Exporting activity_logs..."

    CSV.open(File.join(@export_dir, "activity_logs.csv"), "w", write_headers: true, headers: %w[id action target level description created_at updated_at]) do |csv|
      ActivityLog.order(:id).find_each do |log|
        csv << [
          log.id,
          log.action,
          log.target,
          log.level,
          log.description,
          log.created_at,
          log.updated_at
        ]
      end
    end

    Rails.logger.info "Exported #{ActivityLog.count} activity_logs"
  end

  def export_articles
    Rails.logger.info "Exporting articles and attachments..."

    CSV.open(File.join(@export_dir, "articles.csv"), "w", write_headers: true, headers: %w[id title slug description content status scheduled_at crosspost_mastodon crosspost_twitter crosspost_bluesky send_newsletter created_at updated_at]) do |csv|
      Article.order(:id).find_each do |article|
        # 处理文章内容和附件
        processed_content = process_article_content(article)

        csv << [
          article.id,
          article.title,
          article.slug,
          article.description,
          processed_content,
          article.status,
          article.scheduled_at,
          article.crosspost_mastodon,
          article.crosspost_twitter,
          article.crosspost_bluesky,
          article.send_newsletter,
          article.created_at,
          article.updated_at
        ]
      end
    end

    Rails.logger.info "Exported #{Article.count} articles"
  end

  def process_article_content(article)
    return "" unless article.content.present?

    content_html = article.content.to_trix_html
    return content_html if content_html.blank?

    doc = Nokogiri::HTML.fragment(content_html)

    # 处理action-text-attachment标签
    doc.css("action-text-attachment").each do |attachment|
      process_attachment_element(attachment, article.id, "article")
    end

    # 处理figure标签（Trix编辑器格式）
    doc.css("figure[data-trix-attachment]").each do |figure|
      process_figure_element(figure, article.id, "article")
    end

    # 处理img标签
    doc.css("img").each do |img|
      process_image_element(img, article.id, "article")
    end

    doc.to_html
  end

  def process_attachment_element(attachment, record_id, record_type)
    begin
      content_type = attachment["content-type"]
      original_url = attachment["url"]
      filename = attachment["filename"]

      return unless content_type&.start_with?("image/") && original_url.present? && filename.present?

      Rails.logger.info "Processing attachment: #{filename} (#{original_url})"

      # 下载并保存附件
      new_url = download_and_save_attachment(original_url, filename, record_id, record_type)

      if new_url
        # 更新attachment标签的URL
        attachment["url"] = new_url

        # 更新内部的img标签
        img = attachment.at_css("img")
        img["src"] = new_url if img
      end
    rescue => e
      Rails.logger.error "Error processing attachment element: #{e.message}"
    end
  end

  def process_figure_element(figure, record_id, record_type)
    begin
      attachment_data = JSON.parse(figure["data-trix-attachment"]) rescue nil
      return unless attachment_data

      content_type = attachment_data["contentType"]
      original_url = attachment_data["url"]
      filename = attachment_data["filename"] || File.basename(original_url)

      return unless content_type&.start_with?("image/") && original_url.present?

      Rails.logger.info "Processing figure attachment: #{filename} (#{original_url})"

      # 下载并保存附件
      new_url = download_and_save_attachment(original_url, filename, record_id, record_type)

      if new_url
        # 更新attachment数据
        attachment_data["url"] = new_url
        figure["data-trix-attachment"] = attachment_data.to_json

        # 更新内部的img标签
        img = figure.at_css("img")
        img["src"] = new_url if img
      end
    rescue => e
      Rails.logger.error "Error processing figure element: #{e.message}"
    end
  end

  def process_image_element(img, record_id, record_type)
    begin
      original_url = img["src"]
      return unless original_url.present?

      # 检查是否是本地存储的附件URL
      if original_url.include?("/rails/active_storage/blobs/") || original_url.include?("/rails/active_storage/representations/")
        Rails.logger.info "Processing image element: #{original_url}"

        # 尝试从Active Storage获取blob信息
        blob = extract_blob_from_url(original_url)
        if blob
          filename = blob.filename.to_s
          new_url = download_and_save_attachment(original_url, filename, record_id, record_type)
          img["src"] = new_url if new_url
        end
      end
    rescue => e
      Rails.logger.error "Error processing image element: #{e.message}"
    end
  end

  def download_and_save_attachment(original_url, filename, record_id, record_type)
    begin
      # 创建记录特定的附件目录
      record_attachments_dir = File.join(@attachments_dir, "#{record_type}_#{record_id}")
      FileUtils.mkdir_p(record_attachments_dir)

      # 生成新的文件名
      new_filename = "#{SecureRandom.hex(8)}_#{filename}"
      local_path = File.join(record_attachments_dir, new_filename)

      # 构建完整的URL
      full_url = build_full_url(original_url)
      Rails.logger.info "Attempting to download from URL: #{full_url}"

      # 下载文件
      URI.open(full_url) do |remote_file|
        File.open(local_path, "wb") do |local_file|
          local_file.write(remote_file.read)
        end
      end

      # 返回相对路径
      new_url = "attachments/#{record_type}_#{record_id}/#{new_filename}"
      Rails.logger.info "Successfully downloaded attachment: #{filename} -> #{new_filename}"

      new_url
    rescue => e
      Rails.logger.error "Error downloading attachment #{original_url}: #{e.message}"
      Rails.logger.error "Full URL attempted: #{build_full_url(original_url)}"
      nil
    end
  end

  def build_full_url(original_url)
    return original_url if original_url.start_with?("http")

    # 如果是相对路径，使用应用的基础URL
    base_url = Setting.first&.url.presence || ENV["BASE_URL"].presence || "http://localhost:3000"
    base_url = base_url.chomp("/")

    # 确保URL格式正确
    if original_url.start_with?("/")
      "#{base_url}#{original_url}"
    else
      "#{base_url}/#{original_url}"
    end
  end

  def extract_blob_from_url(url)
    # 从Active Storage URL中提取blob信息
    # 格式通常是 /rails/active_storage/blobs/redirect/:signed_id/*filename
    # 或 /rails/active_storage/representations/redirect/:signed_id/*filename

    match = url.match(/\/rails\/active_storage\/(?:blobs|representations)\/redirect\/([^\/]+)/)
    return nil unless match

    signed_id = match[1]
    begin
      # 尝试找到对应的blob
      blob = ActiveStorage::Blob.find_signed(signed_id)
      Rails.logger.info "Found blob for signed_id #{signed_id}: #{blob&.filename}"
      blob
    rescue => e
      Rails.logger.error "Failed to find blob for signed_id #{signed_id}: #{e.message}"
      nil
    end
  end

  def export_crossposts
    Rails.logger.info "Exporting crossposts..."

    CSV.open(File.join(@export_dir, "crossposts.csv"), "w", write_headers: true, headers: %w[id platform server_url client_key client_secret access_token access_token_secret api_key api_key_secret username app_password enabled created_at updated_at]) do |csv|
      Crosspost.order(:id).find_each do |crosspost|
        csv << [
          crosspost.id,
          crosspost.platform,
          crosspost.server_url,
          crosspost.client_key,
          crosspost.client_secret,
          crosspost.access_token,
          crosspost.access_token_secret,
          crosspost.api_key,
          crosspost.api_key_secret,
          crosspost.username,
          crosspost.app_password,
          crosspost.enabled,
          crosspost.created_at,
          crosspost.updated_at
        ]
      end
    end

    Rails.logger.info "Exported #{Crosspost.count} crossposts"
  end

  def export_listmonks
    Rails.logger.info "Exporting listmonks..."

    CSV.open(File.join(@export_dir, "listmonks.csv"), "w", write_headers: true, headers: %w[id url username api_key list_id template_id enabled created_at updated_at]) do |csv|
      Listmonk.order(:id).find_each do |listmonk|
        csv << [
          listmonk.id,
          listmonk.url,
          listmonk.username,
          listmonk.api_key,
          listmonk.list_id,
          listmonk.template_id,
          listmonk.enabled,
          listmonk.created_at,
          listmonk.updated_at
        ]
      end
    end

    Rails.logger.info "Exported #{Listmonk.count} listmonks"
  end

  def export_pages
    Rails.logger.info "Exporting pages..."

    CSV.open(File.join(@export_dir, "pages.csv"), "w", write_headers: true, headers: %w[id title slug content status redirect_url page_order created_at updated_at]) do |csv|
      Page.order(:id).find_each do |page|
        # 处理页面内容（如果有富文本内容的话）
        content = page.content.present? ? process_page_content(page) : ""

        csv << [
          page.id,
          page.title,
          page.slug,
          content,
          page.status,
          page.redirect_url,
          page.page_order,
          page.created_at,
          page.updated_at
        ]
      end
    end

    Rails.logger.info "Exported #{Page.count} pages"
  end

  def process_page_content(page)
    return "" unless page.content.present?

    content_html = page.content.to_trix_html
    return content_html if content_html.blank?

    doc = Nokogiri::HTML.fragment(content_html)

    # 处理附件（与文章类似）
    doc.css("action-text-attachment").each do |attachment|
      process_attachment_element(attachment, page.id, "page")
    end

    doc.css("figure[data-trix-attachment]").each do |figure|
      process_figure_element(figure, page.id, "page")
    end

    doc.css("img").each do |img|
      process_image_element(img, page.id, "page")
    end

    doc.to_html
  end

  def export_settings
    Rails.logger.info "Exporting settings..."

    CSV.open(File.join(@export_dir, "settings.csv"), "w", write_headers: true, headers: %w[id title description author url time_zone head_code custom_css social_links footer tool_code giscus created_at updated_at]) do |csv|
      Setting.order(:id).find_each do |setting|
        # 处理footer内容（如果有富文本内容的话）
        footer_content = setting.footer.present? ? process_setting_footer(setting) : ""

        csv << [
          setting.id,
          setting.title,
          setting.description,
          setting.author,
          setting.url,
          setting.time_zone,
          setting.head_code,
          setting.custom_css,
          setting.social_links&.to_json,
          footer_content,
          setting.tool_code,
          setting.giscus,
          setting.created_at,
          setting.updated_at
        ]
      end
    end

    Rails.logger.info "Exported #{Setting.count} settings"
  end

  def process_setting_footer(setting)
    return "" unless setting.footer.present?

    footer_html = setting.footer.to_trix_html
    return footer_html if footer_html.blank?

    doc = Nokogiri::HTML.fragment(footer_html)

    # 处理附件
    doc.css("action-text-attachment").each do |attachment|
      process_attachment_element(attachment, setting.id, "setting")
    end

    doc.css("figure[data-trix-attachment]").each do |figure|
      process_figure_element(figure, setting.id, "setting")
    end

    doc.css("img").each do |img|
      process_image_element(img, setting.id, "setting")
    end

    doc.to_html
  end

  def export_social_media_posts
    Rails.logger.info "Exporting social_media_posts..."

    CSV.open(File.join(@export_dir, "social_media_posts.csv"), "w", write_headers: true, headers: %w[id article_id platform url created_at updated_at]) do |csv|
      SocialMediaPost.order(:id).find_each do |post|
        csv << [
          post.id,
          post.article_id,
          post.platform,
          post.url,
          post.created_at,
          post.updated_at
        ]
      end
    end

    Rails.logger.info "Exported #{SocialMediaPost.count} social_media_posts"
  end

  def export_users
    Rails.logger.info "Exporting users..."

    CSV.open(File.join(@export_dir, "users.csv"), "w", write_headers: true, headers: %w[id user_name created_at updated_at]) do |csv|
      User.order(:id).find_each do |user|
        csv << [
          user.id,
          user.user_name,
          user.created_at,
          user.updated_at
        ]
      end
    end

    Rails.logger.info "Exported #{User.count} users"
  end

  def create_zip_file
    @zip_path = "#{@export_dir}.zip"

    # 使用Ruby的zip库创建ZIP文件
    # 修复：使用Zip::OutputStream替代不存在的Zip::File::CREATE常量以兼容rubyzip 3.2.2
    Zip::OutputStream.open(@zip_path) do |zos|
      # 添加CSV文件
      Dir.glob(File.join(@export_dir.to_s, "*.csv")).each do |file|
        zos.put_next_entry(File.basename(file))
        zos.write(File.read(file))
      end

      # 添加附件目录
      if Dir.exist?(@attachments_dir) && !Dir.empty?(@attachments_dir)
        Dir.glob(File.join(@attachments_dir, "**", "*")).each do |file|
          next unless File.file?(file)

          # 计算在zip中的相对路径（相对于导出根目录）
          relative_path = Pathname.new(file).relative_path_from(@export_dir).to_s
          # 规范化为 zip 友好的分隔符（可选）
          relative_path = relative_path.tr("\\", "/")

          zos.put_next_entry(relative_path)
          zos.write(File.binread(file))
        end
      end
    end

    Rails.logger.info "Created ZIP file: #{@zip_path}"

    # 清理临时目录（可选）
    FileUtils.rm_rf(@export_dir)
  end
end
