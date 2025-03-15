class Page < ApplicationRecord
  has_rich_text :content
  include MeiliSearch::Rails

  enum :status, [ :draft, :publish, :schedule, :trash, :shared ]

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :redirect_url, url: true, allow_blank: true

  scope :published, -> { where(status: :publish) }
  scope :by_status, ->(status) { where(status: status) }

  meilisearch do
    # 定义要索引的属性
    attribute :content_plain_text do
      content&.body&.to_plain_text
    end
    searchable_attributes [:title, :slug, :content_plain_text]
    # 可以添加其他需要的配置
    filterable_attributes [:created_at, :updated_at]
    sortable_attributes [:created_at, :updated_at]

    # 其他可选配置
    # ranking_rules ['typo', 'words', 'proximity', 'attribute', 'sort', 'exactness']
    # pagination max_total_hits: 1000
  end

  def to_param
    slug
  end

  def redirect?
    redirect_url.present?
  end
end
