class MigrateArticlesToPages < ActiveRecord::Migration[8.0]
  def change
    Article.where(is_page: true).find_each do |article|
      Page.create!(
        title: article.title,
        content: article.content,
        status: article.status,
        slug: article.slug,
        page_order: article.page_order,
        created_at: article.created_at,
        updated_at: article.updated_at
      )
      end
    end
end
