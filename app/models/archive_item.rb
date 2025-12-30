class ArchiveItem < ApplicationRecord
  belongs_to :article, optional: true

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  def self.normalize_url(value)
    normalized = value.to_s.strip
    return normalized if normalized.blank?

    normalized = "https://#{normalized}" unless normalized.match?(%r{\A[a-z][a-z0-9+\-.]*://}i)
    normalized
  end

  validates :url, presence: true, uniqueness: true, length: { maximum: 2048 }
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid HTTP(S) URL" }

  scope :recent, -> { order(created_at: :desc) }
  scope :pending_or_failed, -> { where(status: [ :pending, :failed ]) }

  before_validation :normalize_url

  def archive!
    update!(status: :pending)
    ArchiveUrlJob.perform_later(id)
  end

  def mark_completed!(file_path:, file_size:)
    update!(
      status: :completed,
      file_path: file_path,
      file_size: file_size,
      archived_at: Time.current,
      error_message: nil
    )
  end

  def mark_failed!(error_message)
    update!(
      status: :failed,
      error_message: error_message
    )
  end

  def file_size_formatted
    return nil unless file_size

    if file_size >= 1_048_576
      "#{(file_size / 1_048_576.0).round(2)} MB"
    elsif file_size >= 1024
      "#{(file_size / 1024.0).round(2)} KB"
    else
      "#{file_size} B"
    end
  end

  private

  def normalize_url
    self.url = self.class.normalize_url(url)
  end
end
