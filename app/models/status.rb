class Status < ApplicationRecord
  has_many :social_media_posts, dependent: :destroy
  accepts_nested_attributes_for :social_media_posts, allow_destroy: true

  if defined?(ENABLE_ALGOLIASEARCH)
    include AlgoliaSearch
    algoliasearch if: :should_index? do
      attribute :text
      searchableAttributes [ "text" ]
    end

  else

    include PgSearch::Model
    pg_search_scope :search_content,
                    against: [ :text ],
                    using: {
                      tsearch: {
                        prefix: true,
                        any_word: true,
                        dictionary: "simple"
                      },
                      trigram: {
                        threshold: 0.3
                      }
                    }
  end
end
