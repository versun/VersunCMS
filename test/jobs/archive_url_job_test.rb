require "test_helper"
require "minitest/mock"

class ArchiveUrlJobTest < ActiveJob::TestCase
  test "completes successfully without extra archive.org submission call" do
    archive_item = ArchiveItem.create!(url: "https://example.com", status: :pending)

    archive_called = false
    received_archive_item = nil
    regenerate_called = false
    regenerated_after_completion = nil

    service = Object.new
    service.define_singleton_method(:archive_url) do |item|
      archive_called = true
      received_archive_item = item
      { file_path: "example.html", file_size: 123 }
    end
    service.define_singleton_method(:regenerate_index!) do
      regenerate_called = true
      regenerated_after_completion = archive_item.reload.completed?
      nil
    end

    SingleFileArchiveService.stub(:new, service) do
      ArchiveUrlJob.perform_now(archive_item.id)
    end

    archive_item.reload
    assert archive_item.completed?, "Expected ArchiveItem to be completed, got #{archive_item.status} (#{archive_item.error_message.inspect})"

    assert archive_called, "Expected URL to be archived"
    assert_equal archive_item.id, received_archive_item&.id
    assert regenerate_called, "Expected index to be regenerated"
    assert regenerated_after_completion, "ArchiveItem should be completed before regenerating index"

    assert_equal "example.html", archive_item.file_path
    assert_equal 123, archive_item.file_size
    assert_nil archive_item.error_message
  end

  test "stores archive.org url on article when present" do
    article = create_published_article
    archive_item = ArchiveItem.create!(url: "https://example.com", status: :pending, article: article)

    archive_called = false
    received_archive_item = nil
    regenerate_called = false
    regenerated_after_completion = nil

    service = Object.new
    service.define_singleton_method(:archive_url) do |item|
      archive_called = true
      received_archive_item = item
      { file_path: "example.html", file_size: 123, ia_url: "https://archive.org/details/example" }
    end
    service.define_singleton_method(:regenerate_index!) do
      regenerate_called = true
      regenerated_after_completion = archive_item.reload.completed?
      nil
    end

    SingleFileArchiveService.stub(:new, service) do
      ArchiveUrlJob.perform_now(archive_item.id)
    end

    archive_item.reload
    assert archive_item.completed?, "Expected ArchiveItem to be completed, got #{archive_item.status} (#{archive_item.error_message.inspect})"

    assert archive_called, "Expected URL to be archived"
    assert_equal archive_item.id, received_archive_item&.id
    assert regenerate_called, "Expected index to be regenerated"
    assert regenerated_after_completion, "ArchiveItem should be completed before regenerating index"

    post = article.social_media_posts.find_by(platform: "internet_archive")
    assert post, "SocialMediaPost should be created"
    assert_equal "https://archive.org/details/example", post.url
  end

  test "discards when browser is missing" do
    archive_item = ArchiveItem.create!(url: "https://example.com", status: :pending)

    service = Object.new
    def service.archive_url(_archive_item)
      raise SingleFileArchiveService::BrowserNotFoundError, "Chromium executable not found."
    end

    SingleFileArchiveService.stub(:new, service) do
      ArchiveUrlJob.perform_now(archive_item.id)
    end

    archive_item.reload
    assert archive_item.failed?
    assert_match(/chrom/i, archive_item.error_message)
  end
end
