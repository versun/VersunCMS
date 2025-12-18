class Tag < ApplicationRecord
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug
  after_save :trigger_static_generation, if: :should_regenerate_static?
  after_destroy :trigger_static_regeneration_on_destroy

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
    return if slug.present? || name.blank?

    # 直接使用名称作为slug，支持中文
    # 只做基本的清理：去除首尾空格，将多个空格替换为单个空格
    slug_candidate = name.to_s.strip.gsub(/\s+/, " ")

    # 确保slug唯一
    base_slug = slug_candidate
    counter = 1
    while Tag.where(slug: slug_candidate).where.not(id: id || 0).exists?
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = slug_candidate
  end

  def should_regenerate_static?
    # Only regenerate if auto-regenerate is enabled for tag updates
    return false unless Setting.first_or_create.auto_regenerate_enabled?("tag_update")
    
    saved_change_to_name?
  end

  def trigger_static_generation
    GenerateStaticFilesJob.perform_later(type: "tag", id: id)
  end

  def trigger_static_regeneration_on_destroy
    # Regenerate tags index when a tag is destroyed
    GenerateStaticFilesJob.perform_later(type: "all")
  end
end
