require "test_helper"

class ArchiveArticleJobTest < ActiveJob::TestCase
  test "creates archive item and enqueues archive url job" do
    ArchiveSetting.create!(
      enabled: true,
      repo_url: "https://github.com/example/archive.git",
      branch: "main",
      git_integration: git_integrations(:github)
    )

    Setting.first.update!(url: "example.com")

    article = create_published_article(title: "Archive Job Article")

    expected_url = [
      "https://example.com",
      Rails.application.config.x.article_route_prefix.to_s.delete_prefix("/"),
      article.slug
    ].reject(&:blank?).join("/")

    assert_enqueued_with(job: ArchiveUrlJob) do
      ArchiveArticleJob.perform_now(article.id)
    end

    archive_item = ArchiveItem.find_by(url: expected_url)
    assert archive_item, "ArchiveItem should be created"
    assert_equal article.id, archive_item.article_id
    assert_equal "Archive Job Article", archive_item.title
    assert archive_item.pending?
  end
end
