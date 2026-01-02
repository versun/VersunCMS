# frozen_string_literal: true

# 自动压缩上传到 Action Text 富文本编辑器中的图片
Rails.application.config.after_initialize do
  ActiveStorage::Attachment.include(ActiveStorageCompression)
end
