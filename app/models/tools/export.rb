module Tools
  class Export
    require "csv"
    require "zip"

    attr_reader :zip_path, :error_message

    def initialize
      @zip_path = nil
      @error_message = nil
    end

    def generate_csv
      begin
        articles = Article.all
        
        csv_data = CSV.generate(headers: true) do |csv|
          csv << ['ID', 'Title', 'Slug', 'Description', 'Status', 'Scheduled At', 'Created At', 'Updated At', 'Is Page', 'Page Order']
          
          articles.each do |article|
            csv << [
              article.id,
              article.title,
              article.slug,
              article.description,
              article.status,
              article.scheduled_at,
              article.created_at,
              article.updated_at,
              article.is_page,
              article.page_order
            ]
          end
        end
        
        csv_data
      rescue => e
        @error_message = "导出失败: #{e.message}"
        nil
      end
    end

    def generate
      generate_csv
    end
  end
end
