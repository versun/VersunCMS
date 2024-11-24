require "zip"
require "json"
require "nokogiri"
require "uri"
require "net/http"

module Tools
  class ImportController < ApplicationController
    def index
    end

    def from_zip
      @import = Tools::ZipImport.new(params[:file])
      if @import.process
        redirect_to tools_import_index_path, notice: "Import completed successfully"
      else
        redirect_to tools_import_index_path, alert: "Import failed: #{@import.error_message}"
      end
    rescue StandardError => e
      Rails.logger.error "ZipImport process error: #{e.message}"
      redirect_to tools_import_index_path, alert: "An unexpected error occurred during import, please contact the administrator"
    ensure
      refresh_pages
      refresh_settings
    end

    def from_wordpress
      @import = Tools::WordPressImport.new(params[:file])
      if @import.process
        redirect_to tools_import_index_path, notice: "WordPress导入成功"
      else
        redirect_to tools_import_index_path, alert: "导入失败: #{@import.error_message}"
      end
    rescue StandardError => e
      Rails.logger.error "WordPress导入错误: #{e.message}"
      redirect_to tools_import_index_path, alert: "导入过程中发生意外错误，请联系管理员"
    ensure
      refresh_pages
      refresh_settings
    end
  end

  class ZipImport
    attr_reader :error_message

    def initialize(file)
      @file = file
      @error_message = nil
      @temp_dir = Rails.root.join("tmp", "zip_import_#{Time.now.to_i}")
      @content_dir = File.join(@temp_dir, "content")
      @media_dir = File.join(@temp_dir, "media")
    end

    def process
      FileUtils.mkdir_p([ @content_dir, @media_dir ])
      extract_zip
      import_articles
      true
    rescue StandardError => e
      @error_message = e.message
      Rails.logger.error "Zip Import Error: #{e.message}"
      false
    ensure
      FileUtils.rm_rf(@temp_dir)
    end

    private

    def extract_zip
      Zip::File.open(@file.path) do |zip_file|
        zip_file.each do |entry|
          entry_path = File.join(@temp_dir, entry.name)
          FileUtils.mkdir_p(File.dirname(entry_path))
          entry.extract(entry_path)
        end
      end
    end

    def import_articles
      articles_json = File.read(File.join(@content_dir, "articles.json"))
      articles_data = JSON.parse(articles_json)

      articles_data.each do |article_data|
        # 处理标签
        # tags = article_data.delete("tags").map do |tag_name|
        #   Tag.find_or_create_by!(name: tag_name)
        # end

        # 获取附件信息
        attachments_data = article_data.delete("attachments") || []

        # 查找现有文章
        existing_article = Article.find_by(slug: article_data["slug"])

        # 如果文章存在，删除它及其附件
        if existing_article
          existing_article.content.embeds.purge if existing_article.content&.embeds&.attached?
          existing_article.destroy
        end

        # 创建新文章
        article = Article.new(article_data.except("content"))
        content_html = article_data["content"]

        # 处理附件
        if attachments_data.any?
          article_media_dir = File.join(@media_dir, article.slug)

          attachments_data.each do |attachment_info|
            filename = attachment_info["filename"]
            file_path = File.join(article_media_dir, filename)

            if File.exist?(file_path)
              File.open(file_path, "rb") do |io|
                blob = ActiveStorage::Blob.create_and_upload!(
                  io: io,
                  filename: filename,
                  content_type: attachment_info["content_type"]
                )
                # 附加到article
                article.content.embeds.attach(blob)

                # 生成新的blob url和sgid
                new_url = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
                new_sgid = blob.attachable_sgid
                # 替换content中的所有相关URL
                encoded_filename = URI.encode_uri_component(filename)
                # 替换主图片URL
                blob_pattern = %r{url="[^"]+/rails/active_storage/blobs/redirect/[^"]+/#{Regexp.escape(encoded_filename)}"}
                content_html.gsub!(blob_pattern, %(url="#{new_url}"))
                # 替换预览图URL
                preview_pattern = %r{src="[^"]+/rails/active_storage/representations/redirect/[^"]+/[^"]+/#{Regexp.escape(encoded_filename)}"}
                content_html.gsub!(preview_pattern, %(src="#{new_url}"))
                # 替换sgid
                sgid_pattern = /sgid="[^"]+"/
                content_html.gsub!(sgid_pattern, %(sgid="#{new_sgid}"))
                Rails.logger.debug "Content after replacement: #{content_html}"
              end
            end
          end
        end
        # 更新文章内容
        article.content = content_html
        # article.tags = tags
        article.save!
      end
    end
  end

  class WordPressImport
    attr_reader :error_message

    def initialize(file)
      @file = file
      @error_message = nil
      @temp_dir = Rails.root.join("tmp", "wp_import_#{Time.now.to_i}")
      @media_dir = File.join(@temp_dir, "media")
    end

    def process
      FileUtils.mkdir_p(@media_dir)
      doc = Nokogiri::XML(@file.read)
      import_articles(doc)
      true
    rescue StandardError => e
      @error_message = e.message
      Rails.logger.error "WordPress Import Error: #{e.message}"
      false
    ensure
      FileUtils.rm_rf(@temp_dir)
    end

    private

    def import_articles(doc)
      doc.xpath("//item").each do |item|
        # Extract article data
        post_type = item.xpath("wp:post_type")&.text
        next unless [ "post", "page" ].include?(post_type)

        title = item.at_xpath("title").text
        created_date = item.at_xpath("wp:post_date").text
        slug = item.at_xpath("wp:post_name", "wp" => "http://wordpress.org/export/1.2/")&.text
        content = item.at_xpath("content:encoded")&.text || ""
        status = item.at_xpath("wp:status", "wp" => "http://wordpress.org/export/1.2/")&.text == "publish" ? :publish : :draft

        if slug.blank?
          wp_post_id = item.at_xpath("wp:post_id", WP_NAMESPACE)&.text
          date = Time.parse(created_date.to_s).strftime("%Y%m%d")
          slug = "#{date}-#{wp_post_id}"
        end

        # # Get tags
        # tags = item.xpath('category[@domain="category"]').map(&:text).map do |tag_name|
        #   Tag.find_or_create_by!(name: tag_name)
        # end

        # Delete existing article if exists
        if existing_article = Article.find_by(slug: slug)
          existing_article.content.embeds.purge if existing_article.content&.embeds&.attached?
          existing_article.destroy
        end

        # Create new article
        article = Article.new(
          title: title,
          slug: URI.decode_www_form_component(slug),
          is_page: post_type == "page",
          status: status,
          created_at: created_date,
          updated_at: item.at_xpath("wp:post_modified")&.text
        )

        # Process images in content
        doc = Nokogiri::HTML(content)
        doc.css("img").each do |img|
          src = img["src"]
          next unless src

          filename = File.basename(URI.parse(src).path)
          file_path = File.join(@media_dir, filename)

          # Download image
          begin
            download_file(src, file_path)

            if File.exist?(file_path)
              File.open(file_path, "rb") do |io|
                blob = ActiveStorage::Blob.create_and_upload!(
                  io: io,
                  filename: filename,
                  content_type: Marcel::MimeType.for(io)
                )

                article.content.embeds.attach(blob)

                # Update image URL in content
                new_url = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
                img["src"] = new_url
                img["url"] = new_url if img["url"]
              end
            end
          rescue StandardError => e
            Rails.logger.error "Failed to download image #{src}: #{e.message}"
          end
        end

        # Save article with processed content
        article.content = doc.to_html
        # article.tags = tags
        article.save!
      end
    end

    def download_file(url, destination)
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          File.open(destination, "wb") do |file|
            file.write(response.body)
          end
        end
      end
    end
  end
end
