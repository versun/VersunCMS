class StaticFile < ApplicationRecord
  has_one_attached :file

  validates :file, presence: true
  validate :file_must_be_attached

  after_create :trigger_static_generation_on_create, if: :should_regenerate_on_create?
  after_update :trigger_static_generation_on_update, if: :should_regenerate_on_update?

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

  def should_regenerate_on_create?
    # Only regenerate if auto-regenerate is enabled for static file uploads
    Setting.first_or_create.auto_regenerate_enabled?("static_file_upload")
  end

  def should_regenerate_on_update?
    # Only regenerate if auto-regenerate is enabled for static file uploads
    return false unless Setting.first_or_create.auto_regenerate_enabled?("static_file_upload")

    # Trigger when filename changes (file was replaced)
    saved_change_to_filename?
  end

  def trigger_static_generation_on_create
    # Regenerate all static files when a new static file is uploaded
    GenerateStaticFilesJob.perform_later(type: "all")
  end

  def trigger_static_generation_on_update
    # Regenerate all static files when a static file is updated
    GenerateStaticFilesJob.perform_later(type: "all")
  end
end
