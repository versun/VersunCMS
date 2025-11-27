class ArticleTag < ApplicationRecord
  belongs_to :article
  belongs_to :tag

  validates :article_id, uniqueness: { scope: :tag_id }
end
