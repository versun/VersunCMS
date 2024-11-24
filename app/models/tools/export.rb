require "zip"
require "erb"

module Tools
  class Export
    attr_reader :error_message, :zip_path

    def initialize
      @error_message = nil
      @temp_dir = Rails.root.join("tmp", "export_#{Time.now.to_i}")
      @zip_path = "#{@temp_dir}.zip"
      @content_dir = File.join(@temp_dir, "json")
      @media_dir = File.join(@temp_dir, "media")
      @static_site_dir = File.join(@temp_dir, "static_site")
    end

    def generate
      FileUtils.mkdir_p([ @content_dir, @media_dir, @static_site_dir ])
      export_articles
      export_settings
      export_backup_settings
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
        
        # 检查是否有附件
        has_embeds = article.content.embeds.any? rescue false
        FileUtils.mkdir_p(article_media_dir) if has_embeds

        # 导出附件
        attachments = []
        if has_embeds
          attachments = article.content.embeds.map do |embed|
            filename = embed.blob.filename.to_s
            path = File.join(article_media_dir, filename)
            File.binwrite(path, embed.blob.download)
            {
              filename: filename,
              byte_size: embed.blob.byte_size,
              content_type: embed.blob.content_type
            }
          end
        end

        # 导出文章数据
        {
          title: article.title,
          content: article.content,
          slug: article.slug,
          status: article.status,
          created_at: article.created_at,
          updated_at: article.updated_at,
          attachments: attachments
        }
      end

      # 将数据写入JSON文件
      File.write(
        File.join(@content_dir, "articles.json"),
        JSON.pretty_generate(articles_data)
      )
    end

    def export_settings
      settings_data = Setting.all.map do |setting|
        {
          title: setting.title,
          description: setting.description,
          author: setting.author,
          url: setting.url,
          time_zone: setting.time_zone,
          footer: setting.footer.to_s,
          social_links: setting.social_links,
          created_at: setting.created_at,
          updated_at: setting.updated_at
        }
      end

      File.write(
        File.join(@content_dir, "settings.json"),
        JSON.pretty_generate(settings_data)
      )
    end

    def export_backup_settings
      backup_settings_data = BackupSetting.all.map do |setting|
        {
          repository_url: setting.repository_url,
          branch_name: setting.branch_name,
          created_at: setting.created_at,
          updated_at: setting.updated_at
        }
      end

      File.write(
        File.join(@content_dir, "backup_settings.json"),
        JSON.pretty_generate(backup_settings_data)
      )
    end

    def create_zip
      Zip::File.open(@zip_path, create: true) do |zipfile|
        add_directory_to_zip(zipfile, @temp_dir)
      end
    end

    def add_directory_to_zip(zipfile, dir)
      Dir.glob("#{dir}/**/*") do |file|
        next if File.directory?(file)
        file_path = file
        zip_path = file.sub("#{@temp_dir}/", "")
        zipfile.add(zip_path, file_path)
      end
    end
  end
end
