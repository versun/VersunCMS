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
      if params[:file].nil?
        redirect_to tools_import_index_path, alert: "Please select a backup file"
        return
      end

      unless params[:file].content_type == "application/zip"
        redirect_to tools_import_index_path, alert: "Invalid file type. Please upload a zip file"
        return
      end

      @import = Tools::DBImport.new
      if @import.restore(params[:file].tempfile.path)
        redirect_to tools_import_index_path, notice: "Database restored successfully"
      else
        redirect_to tools_import_index_path, alert: "Restore failed: #{@import.error_message}"
      end
    rescue StandardError => e
      Rails.logger.error "Database restore error: #{e.message}"
      redirect_to tools_import_index_path, alert: "An unexpected error occurred during restore"
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


  class WordPressImport
    WP_NAMESPACE = { "wp" => "http://wordpress.org/export/1.2/" }
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
        slug = item.at_xpath("wp:post_name", WP_NAMESPACE)&.text
        content = item.at_xpath("content:encoded")&.text || ""
        status = item.at_xpath("wp:status", WP_NAMESPACE)&.text == "publish" ? :publish : :draft

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
          updated_at: item.at_xpath("wp:post_modified")&.text,
          scheduled_at: status == :schedule ? created_date : nil,
          page_order: post_type == "page" ? 0 : nil  # 默认页面顺序为0
        )

        Rails.logger.debug "WordPress Import - New article attributes: #{article.attributes.inspect}"

        begin
          # First save article without content to get id
          article.save!
          Rails.logger.debug "WordPress Import - Article saved: #{article.inspect}"

          # Delete existing FTS record if exists
          ActiveRecord::Base.connection.execute("DELETE FROM article_fts WHERE rowid = ?", article.id)
          Rails.logger.debug "WordPress Import - Deleted existing FTS record"

          # Process content to remove any problematic HTML
          processed_content = ActionController::Base.helpers.strip_tags(content || "")
          Rails.logger.debug "WordPress Import - Processed content length: #{processed_content.length}"

          # Create ActionText content
          action_text_content = ActionText::Content.new(content || "")
          Rails.logger.debug "WordPress Import - Created ActionText content"

          # Create FTS record manually
          sql = ActiveRecord::Base.sanitize_sql_array(
            [
              "INSERT INTO article_fts (rowid, title, content) VALUES (?, ?, ?)",
              article.id,
              article.title || "",
              processed_content
            ]
          )
          ActiveRecord::Base.connection.execute(sql)
          Rails.logger.debug "WordPress Import - Created FTS record"

          # Then set content
          article.content = action_text_content
          article.save!
          Rails.logger.debug "WordPress Import - Article content saved: #{article.content.inspect}"
        rescue StandardError => e
          Rails.logger.error "WordPress Import - Failed to save article: #{e.class} - #{e.message}"
          Rails.logger.error "WordPress Import - Article validation errors: #{article.errors.full_messages}" if article.errors.any?
          Rails.logger.error "WordPress Import - Article attributes: #{article.attributes.inspect}"
          raise e
        end

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
                Rails.logger.debug "WordPress Import - Processing attachment: #{filename}"
                blob = ActiveStorage::Blob.create_and_upload!(
                  io: io,
                  filename: filename,
                  content_type: Marcel::MimeType.for(io)
                )
                Rails.logger.debug "WordPress Import - Blob created: #{blob.inspect}"

                attach_result = article.content.embeds.attach(blob)
                Rails.logger.debug "WordPress Import - Attachment result: #{attach_result.inspect}"
                Rails.logger.debug "WordPress Import - Content after attachment: #{article.content.inspect}"

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
        article.save!
        Rails.logger.debug "WordPress Import - Final save complete: #{article.content.inspect}"
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
