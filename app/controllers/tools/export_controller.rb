require "zip"
require "erb"

module Tools
  class ExportController < ApplicationController
    def index
    end

    def create
      @export = Tools::Export.new()
      if @export.generate
        send_file @export.zip_path, filename: "blog_export_#{Time.now.to_i}.zip", type: "application/zip"
      else
        redirect_to tools_export_index_path, notice: "Export failed: #{@export.error_message}"
      end
    rescue StandardError => e
      Rails.logger.error "An unexpected error occurred during export: #{e.message}"
      redirect_to tools_export_index_path, notice: "An unexpected error occurred during export"
    end
  end

  class Export
    attr_reader :error_message, :zip_path

    def initialize
      @error_message = nil
      @temp_dir = Rails.root.join("tmp", "export_#{Time.now.to_i}")
      @zip_path = "#{@temp_dir}.zip"
      @content_dir = File.join(@temp_dir, "content")
      @media_dir = File.join(@temp_dir, "media")
      @static_site_dir = File.join(@temp_dir, "static_site")
    end

    def generate
      FileUtils.mkdir_p([ @content_dir, @media_dir, @static_site_dir ])
      export_articles
      create_zip
      true
    rescue StandardError => e
      @error_message = e.message
      Rails.logger.error "Export failed: #{e.message}"
      false
    ensure
      FileUtils.rm_rf(@temp_dir)
    end

    private
    def export_articles
      articles_data = Article.all.map do |article|
        # 创建文章专属的媒体文件夹（如果有附件的话）
        article_media_dir = File.join(@media_dir, article.slug)
        attachments_data = []
        
        if article.content.embeds.any?
          FileUtils.mkdir_p(article_media_dir)
          
          # 处理并导出附件信息
          article.content.embeds.each do |embed|
            attachments_data << {
              filename: embed.blob.filename.to_s,
              byte_size: embed.blob.byte_size,
              checksum: embed.blob.checksum,
              content_type: embed.blob.content_type
            }
            
            # 导出附件文件
            filepath = File.join(article_media_dir, embed.blob.filename.to_s)
            File.open(filepath, "wb") do |file|
              file.write(embed.blob.download)
            end
          end
        end

        # 导出文章数据
        article.as_json(
          except: [:id]
        ).merge(
          content: article.content,
          attachments: attachments_data  # 修改为包含更多附件信息
        )
      end

      # 将所有文章数据写入JSON文件
      filename = File.join(@content_dir, "articles.json")
      File.write(filename, JSON.pretty_generate(articles_data))
    end

    def create_zip
      Zip::File.open(@zip_path, Zip::File::CREATE) do |zipfile|
        Dir["#{@temp_dir}/**/**"].each do |file|
          zipfile.add(file.sub("#{@temp_dir}/", ""), file)
        end
      end
    end
  end
end
