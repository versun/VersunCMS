class Page < ApplicationRecord
  has_rich_text :content
  has_many :comments, as: :commentable, dependent: :destroy
  enum :status, [ :draft, :publish, :schedule, :trash, :shared ]
  enum :content_type, { rich_text: "rich_text", html: "html" }, default: "rich_text"

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :redirect_url, url: true, allow_blank: true
  validates :html_content, presence: true, if: -> { html? }
  validate :rich_text_content_presence

  scope :published, -> { where(status: :publish) }
  scope :by_status, ->(status) { where(status: status) }

  def to_param
    slug
  end

  def redirect?
    redirect_url.present?
  end

  # 根据content_type返回相应的内容
  def rendered_content
    if html?
      html_content
    else
      content
    end
  end

  private

  def rich_text_content_presence
    if rich_text?
      text = content.present? ? content.to_plain_text.to_s.strip : ""
      if text.blank?
        errors.add(:content, "can't be blank")
      end
    end
  end

end
