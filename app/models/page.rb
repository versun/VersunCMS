class Page < ApplicationRecord
  has_rich_text :content
  enum :status, [ :draft, :publish, :schedule, :trash, :shared ]

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :published, -> { where(status: :publish) }
  scope :by_status, ->(status) { where(status: status) }

  def to_param
    slug
  end
end
