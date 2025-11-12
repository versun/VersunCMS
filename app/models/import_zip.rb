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
    
    # 创建导入目录
    FileUtils.mkdir_p(@import_dir)
  end

  def import_data
    ActivityLog.create!(
      action: "initiated",
      target: "zip_import",
      level: :info,
      description: "Start ZIP import from: #{@zip_path}"
    )

    # 解压ZIP文件
    extract_zip_file

    # 导入各个数据表
    import_activity_logs
    import_articles
    import_crossposts
    import_listmonks
    import_pages

    ActivityLog.create!(
      action: "completed",
      target: "zip_import",
      level: :info,
      description: "ZIP import completed successfully from: #{@zip_path}"
    )

    # 清理临时目录
    FileUtils.rm_rf(@import_dir)
    
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
  end

  def error_message
    @error_message
  end

  private

  def extract_zip_file
    Rails.logger.info "Extracting ZIP file: #{@zip_path}"
    
    Zip::File.open(@zip_path) do |zip_file|
      zip_file.each do |entry|
        # 跳过目录条目
        next if entry.directory?
        
        # 构建解压路径
        extract_path = File.join(@import_dir.to_s, entry.name)
        FileUtils.mkdir_p(File.dirname(extract_path))
        
        # 手动写入文件内容，避免ZIP库的权限问题
        begin
          File.open(extract_path, 'wb') do |f|
            f.write(entry.get_input_stream.read)
          end
          Rails.logger.info "Extracted: #{entry.name} -> #{extract_path}"
        rescue => e
          Rails.logger.error "Failed to extract #{entry.name}: #{e.message}"
          raise
        end
      end
    end
    
    Rails.logger.info "ZIP file extracted to: #{@import_dir}"
  end

  def import_activity_logs
    csv_path = File.join(@import_dir, 'activity_logs.csv')
    return unless File.exist?(csv_path)

    Rails.logger.info "Importing activity logs..."
    
    CSV.foreach(csv_path, headers: true) do |row|
      ActivityLog.create!(
        action: row['action'],
        target: row['target'],
        level: row['level'],
        description: row['description'],
        created_at: row['created_at'],
        updated_at: row['updated_at']
      )
    end
    
    Rails.logger.info "Activity logs imported successfully"
  end

  def import_articles
    csv_path = File.join(@import_dir, 'articles.csv')
    return unless File.exist?(csv_path)

    Rails.logger.info "Importing articles..."
    imported_count = 0
    skipped_count = 0
    
    CSV.foreach(csv_path, headers: true) do |row|
      # 检查是否已存在相同slug的文章
      if Article.exists?(slug: row['slug'])
        Rails.logger.info "Article with slug '#{row['slug']}' already exists, skipping..."
        skipped_count += 1
        next
      end
      
      # 处理文章内容（恢复附件引用）
      processed_content = process_imported_content(row['content'])
      
      Article.create!(
        title: row['title'],
        slug: row['slug'],
        description: row['description'],
        content: processed_content,
        status: row['status'],
        scheduled_at: row['scheduled_at'],
        crosspost_mastodon: row['crosspost_mastodon'],
        crosspost_twitter: row['crosspost_twitter'],
        crosspost_bluesky: row['crosspost_bluesky'],
        send_newsletter: row['send_newsletter'],
        created_at: row['created_at'],
        updated_at: row['updated_at']
      )
      imported_count += 1
    end
    
    Rails.logger.info "Articles import completed: #{imported_count} imported, #{skipped_count} skipped"
  end

  def import_crossposts
    csv_path = File.join(@import_dir, 'crossposts.csv')
    return unless File.exist?(csv_path)

    Rails.logger.info "Importing crossposts..."
    imported_count = 0
    skipped_count = 0
    
    CSV.foreach(csv_path, headers: true) do |row|
      # 检查是否已存在相同平台的crosspost
      if Crosspost.exists?(platform: row['platform'])
        Rails.logger.info "Crosspost for platform '#{row['platform']}' already exists, skipping..."
        skipped_count += 1
        next
      end
      
      Crosspost.create!(
        platform: row['platform'],
        server_url: row['server_url'],
        client_key: row['client_key'],
        client_secret: row['client_secret'],
        access_token: row['access_token'],
        access_token_secret: row['access_token_secret'],
        api_key: row['api_key'],
        api_key_secret: row['api_key_secret'],
        username: row['username'],
        app_password: row['app_password'],
        enabled: row['enabled'],
        created_at: row['created_at'],
        updated_at: row['updated_at']
      )
      imported_count += 1
    end
    
    Rails.logger.info "Crossposts import completed: #{imported_count} imported, #{skipped_count} skipped"
  end

  def import_listmonks
    csv_path = File.join(@import_dir, 'listmonks.csv')
    return unless File.exist?(csv_path)

    Rails.logger.info "Importing listmonks..."
    imported_count = 0
    skipped_count = 0
    
    CSV.foreach(csv_path, headers: true) do |row|
      # 检查是否已存在相同URL的listmonk
      if Listmonk.exists?(url: row['url'])
        Rails.logger.info "Listmonk with URL '#{row['url']}' already exists, skipping..."
        skipped_count += 1
        next
      end
      
      Listmonk.create!(
        url: row['url'],
        username: row['username'],
        api_key: row['api_key'],
        list_id: row['list_id'],
        template_id: row['template_id'],
        enabled: row['enabled'],
        created_at: row['created_at'],
        updated_at: row['updated_at']
      )
      imported_count += 1
    end
    
    Rails.logger.info "Listmonks import completed: #{imported_count} imported, #{skipped_count} skipped"
  end

  def import_pages
    csv_path = File.join(@import_dir, 'pages.csv')
    return unless File.exist?(csv_path)

    Rails.logger.info "Importing pages..."
    imported_count = 0
    skipped_count = 0
    
    CSV.foreach(csv_path, headers: true) do |row|
      # 检查是否已存在相同slug的页面
      if Page.exists?(slug: row['slug'])
        Rails.logger.info "Page with slug '#{row['slug']}' already exists, skipping..."
        skipped_count += 1
        next
      end
      
      # 处理页面内容（恢复附件引用）
      processed_content = process_imported_content(row['content'])
      
      Page.create!(
        title: row['title'],
        slug: row['slug'],
        content: processed_content,
        status: row['status'],
        redirect_url: row['redirect_url'],
        page_order: row['page_order'],
        created_at: row['created_at'],
        updated_at: row['updated_at']
      )
      imported_count += 1
    end
    
    Rails.logger.info "Pages import completed: #{imported_count} imported, #{skipped_count} skipped"
  end

  def process_imported_content(content)
    return content if content.blank?

    doc = Nokogiri::HTML.fragment(content)
    
    # 处理附件引用，重新上传到Active Storage
    doc.css('action-text-attachment').each do |attachment|
      process_imported_attachment(attachment)
    end
    
    doc.css('figure[data-trix-attachment]').each do |figure|
      process_imported_figure(figure)
    end
    
    doc.css('img').each do |img|
      process_imported_image(img)
    end
    
    doc.to_html
  end

  def process_imported_attachment(attachment)
    original_url = attachment['url']
    return unless original_url.present?
    
    # 检查是否是相对路径（导出的附件）
    if original_url.include?('attachments/')
      # 从本地导入的附件路径中提取文件
      attachment_path = File.join(@import_dir, original_url)
      return unless File.exist?(attachment_path)
      
      begin
        # 重新上传到Active Storage
        File.open(attachment_path) do |file|
          content_type = attachment['content-type'] || 'application/octet-stream'
          filename = attachment['filename'] || File.basename(attachment_path)
          
          blob = ActiveStorage::Blob.create_and_upload!(
            io: file,
            filename: filename,
            content_type: content_type
          )
          
          # 更新URL为新的Active Storage URL
          relative_url = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
          attachment['url'] = relative_url
          
          # 更新内部的img标签
          img = attachment.at_css('img')
          img['src'] = relative_url if img
        end
      rescue => e
        Rails.logger.error "Error processing imported attachment: #{e.message}"
      end
    else
      # 如果不是导出的附件，保持原样
      Rails.logger.info "Skipping non-imported attachment URL: #{original_url}"
    end
  end

  def process_imported_figure(figure)
    attachment_data = JSON.parse(figure['data-trix-attachment']) rescue nil
    return unless attachment_data
    
    original_url = attachment_data['url']
    return unless original_url.present?
    
    # 检查是否是相对路径（导出的附件）
    if original_url.include?('attachments/')
      # 从本地导入的附件路径中提取文件
      attachment_path = File.join(@import_dir, original_url)
      return unless File.exist?(attachment_path)
      
      begin
        # 重新上传到Active Storage
        File.open(attachment_path) do |file|
          filename = attachment_data['filename'] || File.basename(attachment_path)
          content_type = attachment_data['contentType'] || 'application/octet-stream'
          
          blob = ActiveStorage::Blob.create_and_upload!(
            io: file,
            filename: filename,
            content_type: content_type
          )
          
          # 更新URL为新的Active Storage URL
          relative_url = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
          attachment_data['url'] = relative_url
          figure['data-trix-attachment'] = attachment_data.to_json
          
          # 更新内部的img标签
          img = figure.at_css('img')
          img['src'] = relative_url if img
        end
      rescue => e
        Rails.logger.error "Error processing imported figure: #{e.message}"
      end
    else
      # 如果不是导出的附件，保持原样
      Rails.logger.info "Skipping non-imported figure URL: #{original_url}"
    end
  end

  def process_imported_image(img)
    original_url = img['src']
    return unless original_url.present?
    
    # 只处理本地导入的附件
    return unless original_url.include?('attachments/') && !original_url.start_with?('http')
    
    # 从本地导入的附件路径中提取文件
    attachment_path = File.join(@import_dir, original_url)
    return unless File.exist?(attachment_path)
    
    begin
      # 重新上传到Active Storage
      File.open(attachment_path) do |file|
        filename = File.basename(attachment_path)
        content_type = `file --brief --mime-type #{attachment_path.shellescape}`.strip rescue 'application/octet-stream'
        
        blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: filename,
          content_type: content_type
        )
        
        # 更新URL为新的Active Storage URL
        relative_url = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
        img['src'] = relative_url
        
        Rails.logger.info "Successfully processed imported image: #{filename} -> #{relative_url}"
      end
    rescue => e
      Rails.logger.error "Error processing imported image: #{e.message}"
    end
  end
end