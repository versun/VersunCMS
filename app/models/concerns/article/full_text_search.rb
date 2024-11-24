module Article::FullTextSearch
  extend ActiveSupport::Concern

  included do
    has_one :article_fts, foreign_key: "rowid"
  end

  class_methods do
    def full_text_search(input:, limit:)
      where("article_fts.title LIKE ? OR article_fts.content LIKE ?", "%#{input}%", "%#{input}%")
      .joins(:article_fts)
      .limit(limit)
      .distinct
    end
  end

  def find_or_create_article_fts
    return if article_fts

    sql = ActiveRecord::Base.sanitize_sql_array(
      [
        "INSERT INTO article_fts (rowid, title, content) VALUES (?, ?, ?)",
        id,
        title || "",
        content.to_plain_text
      ]
    )
    ActiveRecord::Base.connection.execute(sql)
  end
end
