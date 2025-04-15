class SocialMediaPost < ApplicationRecord
  belongs_to :article, optional: true
  belongs_to :status, optional: true
  validates :platform, presence: true
  validates :platform, uniqueness: { scope: :article_id }, if: :article_id?
  validates :platform, uniqueness: { scope: :status_id }, if: :status_id?
  validate :must_belong_to_one_parent

  private

  def must_belong_to_one_parent
    if article_id.present? && status_id.present?
      errors.add(:base, "can only belong to either an article or a status, not both")
    elsif article_id.blank? && status_id.blank?
      errors.add(:base, "must belong to either an article or a status")
    end
  end
end