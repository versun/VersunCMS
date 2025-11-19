class WordpressExport
  require "nokogiri"
  require "base64"
  require "zip"
  require "fileutils"
  require "open-uri"

  attr_reader :export_path, :error_message, :attachments_dir

  def initialize
    @export_path = Rails.root.join("tmp", "exports", "wordpress_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.xml")
    @attachments_dir = File.join(File.dirname(@export_path), "wordpress_attachments_#{Time.current.strftime('%Y%m%d_%H%M%S')}")
    @error_message = nil

    FileUtils.mkdir_p(File.dirname(@export_path))
    FileUtils.mkdir_p(@attachments_dir)
  end

  def generate
    begin
      Rails.logger.info "Starting WordPress export..."

      # 创建WordPress WXR格式的XML文档
      doc = create_wxr_document

      # 添加基础站点信息
      add_site_info(doc)

      # 添加作者信息
      add_authors(doc)

      # 添加分类和标签（基于文章的状态和标签）
      add_categories(doc)

      # 添加文章
      add_posts(doc)

      # 添加页面
      add_pages(doc)

      # 保存XML文件
      save_xml_file(doc)

      # 创建包含附件的ZIP文件
      create_zip_with_attachments

      Rails.logger.info "WordPress export completed successfully!"
      true

    rescue => e
      @error_message = e.message
      Rails.logger.error "WordPress export failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  private

  def create_wxr_document
    doc = Nokogiri::XML::Document.new

    # 创建根节点
    rss = Nokogiri::XML::Node.new("rss", doc)
    rss["version"] = "2.0"
    rss["xmlns:excerpt"] = "http://wordpress.org/export/1.2/excerpt/"
    rss["xmlns:content"] = "http://purl.org/rss/1.0/modules/content/"
    rss["xmlns:wfw"] = "http://wellformedweb.org/CommentAPI/"
    rss["xmlns:dc"] = "http://purl.org/dc/elements/1.1/"
    rss["xmlns:wp"] = "http://wordpress.org/export/1.2/"

    doc.add_child(rss)

    # 创建channel节点
    channel = Nokogiri::XML::Node.new("channel", doc)
    rss.add_child(channel)

    doc
  end

  def add_site_info(doc)
    channel = doc.at_css("channel")
    setting = Setting.first if Setting.table_exists?

    # 基本信息
    add_text_node(channel, "title", setting&.title || "VersunCMS Site")
    add_text_node(channel, "link", setting&.url || "http://localhost:3000")
    add_text_node(channel, "description", setting&.description || "")
    add_text_node(channel, "pubDate", Time.current.rfc822)
    add_text_node(channel, "language", "zh-CN")
    add_text_node(channel, "wp:wxr_version", "1.2")
    add_text_node(channel, "wp:base_site_url", setting&.url || "http://localhost:3000")
    add_text_node(channel, "wp:base_blog_url", setting&.url || "http://localhost:3000")
  end

  def add_authors(doc)
    channel = doc.at_css("channel")

    # 添加所有用户作为作者
    if User.table_exists?
      User.find_each do |user|
        author = Nokogiri::XML::Node.new("wp:author", doc)

        add_text_node(author, "wp:author_id", user.id)
        add_text_node(author, "wp:author_login", user.user_name)
        add_text_node(author, "wp:author_email", "") # 没有邮箱字段
        add_text_node(author, "wp:author_display_name", user.user_name)
        add_text_node(author, "wp:author_first_name", "")
        add_text_node(author, "wp:author_last_name", "")

        channel.add_child(author)
      end
    else
      # 如果没有用户表，添加一个默认作者
      author = Nokogiri::XML::Node.new("wp:author", doc)

      add_text_node(author, "wp:author_id", 1)
      add_text_node(author, "wp:author_login", "admin")
      add_text_node(author, "wp:author_email", "admin@example.com")
      add_text_node(author, "wp:author_display_name", "Admin")
      add_text_node(author, "wp:author_first_name", "")
      add_text_node(author, "wp:author_last_name", "")

      channel.add_child(author)
    end
  end

  def add_categories(doc)
    channel = doc.at_css("channel")

    return unless Article.table_exists?

    # 基于文章状态创建分类
    Article.statuses.each do |status, _value|
      category = Nokogiri::XML::Node.new("wp:category", doc)

      add_text_node(category, "wp:term_id", status.hash.abs)
      add_text_node(category, "wp:category_nicename", status)
      add_text_node(category, "wp:cat_name", status.humanize)

      channel.add_child(category)
    end
  end

  def add_posts(doc)
    channel = doc.at_css("channel")
    setting = Setting.first if Setting.table_exists?

    return unless Article.table_exists?

    # 导出所有文章
    Article.find_each do |article|
      item = Nokogiri::XML::Node.new("item", doc)

      # 基本信息
      add_text_node(item, "title", article.title)
      add_text_node(item, "link", "#{setting&.url}/#{article.slug}")
      add_text_node(item, "pubDate", article.created_at.rfc822)
      add_text_node(item, "dc:creator", "admin")
      add_text_node(item, "guid", "#{setting&.url}/#{article.slug}")
      add_text_node(item, "description", article.description || "")

      # 内容
      content = article.content.present? ? article.content.to_trix_html : ""
      add_cdata_node(item, "content:encoded", process_content_for_wordpress(content, article))

      # excerpt
      add_cdata_node(item, "excerpt:encoded", article.description || "")

      # WordPress特定信息
      add_text_node(item, "wp:post_id", article.id)
      add_text_node(item, "wp:post_date", article.created_at.strftime("%Y-%m-%d %H:%M:%S"))
      add_text_node(item, "wp:post_date_gmt", article.created_at.utc.strftime("%Y-%m-%d %H:%M:%S"))
      add_text_node(item, "wp:comment_status", "open")
      add_text_node(item, "wp:ping_status", "open")
      add_text_node(item, "wp:post_name", article.slug)
      add_text_node(item, "wp:status", wordpress_status(article.status))
      add_text_node(item, "wp:post_parent", 0)
      add_text_node(item, "wp:menu_order", 0)
      add_text_node(item, "wp:post_type", "post")
      add_text_node(item, "wp:post_password", "")
      add_text_node(item, "wp:is_sticky", 0)

      # 分类（基于状态）
      category = Nokogiri::XML::Node.new("category", doc)
      category["domain"] = "category"
      category["nicename"] = article.status
      category.content = article.status.humanize
      item.add_child(category)

      # 添加文章标签（如果有的话）
      tag = Nokogiri::XML::Node.new("category", doc)
      tag["domain"] = "post_tag"
      tag["nicename"] = article.status
      tag.content = article.status.humanize
      item.add_child(tag)

      channel.add_child(item)
    end
  end

  def add_pages(doc)
    channel = doc.at_css("channel")
    setting = Setting.first if Setting.table_exists?

    return unless Page.table_exists?

    # 导出所有页面
    Page.find_each do |page|
      item = Nokogiri::XML::Node.new("item", doc)

      # 基本信息
      add_text_node(item, "title", page.title)
      add_text_node(item, "link", "#{setting&.url}/pages/#{page.slug}")
      add_text_node(item, "pubDate", page.created_at.rfc822)
      add_text_node(item, "dc:creator", "admin")
      add_text_node(item, "guid", "#{setting&.url}/pages/#{page.slug}")
      add_text_node(item, "description", "")

      # 内容
      content = page.content.present? ? page.content.to_trix_html : ""
      add_cdata_node(item, "content:encoded", process_content_for_wordpress(content, page))

      # excerpt
      add_cdata_node(item, "excerpt:encoded", "")

      # WordPress特定信息
      add_text_node(item, "wp:post_id", "page_#{page.id}")
      add_text_node(item, "wp:post_date", page.created_at.strftime("%Y-%m-%d %H:%M:%S"))
      add_text_node(item, "wp:post_date_gmt", page.created_at.utc.strftime("%Y-%m-%d %H:%M:%S"))
      add_text_node(item, "wp:comment_status", "closed")
      add_text_node(item, "wp:ping_status", "closed")
      add_text_node(item, "wp:post_name", page.slug)
      add_text_node(item, "wp:status", wordpress_status(page.status))
      add_text_node(item, "wp:post_parent", 0)
      add_text_node(item, "wp:menu_order", page.page_order)
      add_text_node(item, "wp:post_type", "page")
      add_text_node(item, "wp:post_password", "")
      add_text_node(item, "wp:is_sticky", 0)

      # 重定向URL（如果有的话）
      if page.redirect_url.present?
        meta = Nokogiri::XML::Node.new("wp:postmeta", doc)
        add_text_node(meta, "wp:meta_key", "redirect_url")
        add_cdata_node(meta, "wp:meta_value", page.redirect_url)
        item.add_child(meta)
      end

      channel.add_child(item)
    end
  end

  def process_content_for_wordpress(content, record)
    return "" unless content.present?

    doc = Nokogiri::HTML.fragment(content)

    # 处理图片附件
    doc.css("img").each do |img|
      process_wordpress_image(img, record)
    end

    # 处理action-text-attachment
    doc.css("action-text-attachment").each do |attachment|
      process_wordpress_attachment(attachment, record)
    end

    # 处理figure标签
    doc.css("figure[data-trix-attachment]").each do |figure|
      process_wordpress_figure(figure, record)
    end

    doc.to_html
  end

  def process_wordpress_image(img, record)
    original_src = img["src"]
    return unless original_src.present?

    # 下载图片到本地
    local_filename = download_attachment(original_src, record)

    if local_filename
      # 更新图片src为相对路径
      img["src"] = "wp-content/uploads/#{local_filename}"

      # 添加WordPress图片类
      existing_class = img["class"] || ""
      img["class"] = "#{existing_class} wp-image".strip
    end
  end

  def process_wordpress_attachment(attachment, record)
    content_type = attachment["content-type"]
    original_url = attachment["url"]
    filename = attachment["filename"]

    return unless content_type&.start_with?("image/") && original_url.present? && filename.present?

    # 下载附件
    local_filename = download_attachment(original_url, record, filename)

    if local_filename
      # 创建WordPress图片链接
      img = attachment.at_css("img")
      if img
        img["src"] = "wp-content/uploads/#{local_filename}"
        existing_class = img["class"] || ""
        img["class"] = "#{existing_class} wp-image".strip
      end
    end
  end

  def process_wordpress_figure(figure, record)
    attachment_data = JSON.parse(figure["data-trix-attachment"]) rescue nil
    return unless attachment_data

    content_type = attachment_data["contentType"]
    original_url = attachment_data["url"]
    filename = attachment_data["filename"] || File.basename(original_url)

    return unless content_type&.start_with?("image/") && original_url.present?

    # 下载附件
    local_filename = download_attachment(original_url, record, filename)

    if local_filename
      # 更新figure中的图片
      img = figure.at_css("img")
      if img
        img["src"] = "wp-content/uploads/#{local_filename}"
        existing_class = img["class"] || ""
        img["class"] = "#{existing_class} wp-image".strip
      end
    end
  end

  def download_attachment(url, record, filename = nil)
    begin
      filename ||= File.basename(url)
      timestamp = Time.current.strftime("%Y/%m")
      local_dir = File.join(@attachments_dir, timestamp)
      FileUtils.mkdir_p(local_dir)

      local_path = File.join(local_dir, filename)

      # 下载文件
      full_url = url.start_with?("http") ? url : "#{Setting.first&.url}#{url}"

      URI.open(full_url) do |remote_file|
        File.open(local_path, "wb") do |local_file|
          local_file.write(remote_file.read)
        end
      end

      "#{timestamp}/#{filename}"
    rescue => e
      Rails.logger.error "Failed to download attachment #{url}: #{e.message}"
      nil
    end
  end

  def wordpress_status(status)
    case status.to_s
    when "publish"
      "publish"
    when "draft"
      "draft"
    when "schedule"
      "future"
    when "trash"
      "trash"
    else
      "draft"
    end
  end

  def add_text_node(parent, name, content)
    node = Nokogiri::XML::Node.new(name, parent.document)
    node.content = content.to_s
    parent.add_child(node)
  end

  def add_cdata_node(parent, name, content)
    node = Nokogiri::XML::Node.new(name, parent.document)
    cdata = Nokogiri::XML::CDATA.new(parent.document, content.to_s)
    node.add_child(cdata)
    parent.add_child(node)
  end

  def save_xml_file(doc)
    # 格式化XML
    doc.encoding = "UTF-8"

    # 保存到文件
    File.open(@export_path, "w:UTF-8") do |file|
      file.write(doc.to_xml)
    end

    Rails.logger.info "WordPress WXR file saved to: #{@export_path}"
  end

  def create_zip_with_attachments
    return @export_path unless Dir.exist?(@attachments_dir) && !Dir.empty?(@attachments_dir)

    zip_path = "#{@export_path}.zip"

    Zip::OutputStream.open(zip_path) do |zos|
      # 添加XML文件
      zos.put_next_entry(File.basename(@export_path))
      zos.write(File.read(@export_path))

      # 添加附件
      Dir.glob(File.join(@attachments_dir, "**", "*")).each do |file|
        next unless File.file?(file)

        relative_path = Pathname.new(file).relative_path_from(Pathname.new(@attachments_dir)).to_s
        relative_path = "wp-content/uploads/#{relative_path}"

        zos.put_next_entry(relative_path)
        zos.write(File.binread(file))
      end
    end

    # 清理临时文件
    FileUtils.rm_rf(@attachments_dir)
    FileUtils.rm(@export_path) if File.exist?(@export_path)

    Rails.logger.info "WordPress export ZIP created: #{zip_path}"
    zip_path
  end
end
