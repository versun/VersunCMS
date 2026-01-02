# frozen_string_literal: true

# 自动压缩上传到 Action Text 富文本编辑器中的图片
module ActiveStorageCompression
  extend ActiveSupport::Concern

  included do
    # Action Text 图片上传后压缩
    after_commit :compress_trix_image, on: :create, if: -> { image_attachment? }
  end

  private

  def image_attachment?
    blob.present? && blob.content_type&.start_with?("image/")
  end

  def compress_trix_image
    return unless image_attachment?

    # 只处理富文本编辑器的图片 (embeds)
    return unless name == "embeds"

    # 使用 ruby-vips 压缩图片
    begin
      compress_image
    rescue => e
      Rails.logger.error "压缩图片失败: #{e.message}"
    end
  end

  def compress_image
    # 获取原始文件
    original_path = blob.service.path_for(blob.key)
    return unless File.exist?(original_path)

    # 使用 ruby-vips 压缩
    image = Vips::Image.new_from_file(original_path)

    # 压缩质量设置
    quality = 80

    # 保存压缩后的图片
    compressed_path = "#{original_path}.compressed"
    image.write_to_file(compressed_path, Q: quality)

    # 替换原文件
    FileUtils.mv(compressed_path, original_path)

    # 更新 blob 的 byte_size 和 checksum
    new_size = File.size(original_path)
    blob.update!(byte_size: new_size)

    Rails.logger.info "图片压缩完成: #{blob.filename} (#{new_size} bytes)"
  end
end
