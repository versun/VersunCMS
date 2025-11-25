class StaticFile < ApplicationRecord
  has_one_attached :file

  validates :file, presence: true
  validate :file_must_be_attached

  # 获取文件的公开访问路径
  def public_path
    "/static/#{filename}" if filename.present?
  end

  # 获取文件大小（字节）
  def file_size
    file.blob.byte_size if file.attached?
  end

  # 获取文件大小（人类可读）
  def file_size_human
    return nil unless file.attached?

    size = file.blob.byte_size
    if size < 1024
      "#{size} B"
    elsif size < 1024 * 1024
      "#{(size / 1024.0).round(2)} KB"
    else
      "#{(size / (1024.0 * 1024)).round(2)} MB"
    end
  end

  # 获取内容类型
  def content_type
    file.blob.content_type if file.attached?
  end

  private

  def file_must_be_attached
    errors.add(:file, "must be attached") unless file.attached?
  end
end
