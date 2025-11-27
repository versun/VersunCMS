class Tag < ApplicationRecord
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug

  scope :alphabetical, -> { order(:name) }

  # Find or create tags by comma-separated names
  def self.find_or_create_by_names(names_string)
    return [] if names_string.blank?

    names_string.split(",").map(&:strip).reject(&:blank?).uniq.map do |name|
      find_or_create_by(name: name)
    end
  end

  # Count of articles using this tag
  def articles_count
    articles.count
  end

  private

  def generate_slug
    self.slug = name.to_s.parameterize if name.present? && slug.blank?
  end
end
