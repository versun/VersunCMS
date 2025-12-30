require "test_helper"
require "minitest/mock"

class Admin::SourcesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:admin)
    sign_in(@user)
  end

  test "archive returns 422 when archive not configured" do
    post "/admin/sources/archive", params: { url: "https://example.com" }, as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal "Archive is not configured", body["error"]
  end

  test "archive queues job and returns archive_item_id" do
    ArchiveSetting.create!(
      enabled: true,
      repo_url: "https://github.com/example/archive-repo.git",
      branch: "main",
      git_integration: git_integrations(:github)
    )

    assert_enqueued_with(job: ArchiveUrlJob) do
      post "/admin/sources/archive", params: { url: "https://example.com" }, as: :json
    end

    assert_response :success
    body = response.parsed_body
    assert_equal true, body["success"]
    assert body["archive_item_id"].present?, "Expected archive_item_id to be returned"
    assert_equal "pending", body["status"]

    archive_item = ArchiveItem.find(body["archive_item_id"])
    assert_equal "https://example.com", archive_item.url
    assert_equal "pending", archive_item.status
  end

  test "archive returns cached url when already archived" do
    ArchiveSetting.create!(
      enabled: true,
      repo_url: "https://github.com/example/archive-repo.git",
      branch: "main",
      git_integration: git_integrations(:github)
    )

    ArchiveItem.create!(url: "https://example.com", status: :completed, file_path: "example.html", file_size: 123)

    assert_no_enqueued_jobs do
      post "/admin/sources/archive", params: { url: "https://example.com" }, as: :json
    end

    assert_response :success
    body = response.parsed_body
    assert_equal true, body["success"]
    assert_equal "https://raw.githubusercontent.com/example/archive-repo/main/example.html", body["archived_url"]
  end

  test "archive_status returns completed with url when done" do
    ArchiveSetting.create!(
      enabled: true,
      repo_url: "https://github.com/example/archive-repo.git",
      branch: "main",
      git_integration: git_integrations(:github)
    )

    archive_item = ArchiveItem.create!(
      url: "https://example.com",
      status: :completed,
      file_path: "example.html",
      file_size: 123
    )

    get "/admin/sources/archive_status/#{archive_item.id}", as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "completed", body["status"]
    assert_equal "https://raw.githubusercontent.com/example/archive-repo/main/example.html", body["archived_url"]
  end

  test "archive_status returns failed with error message" do
    archive_item = ArchiveItem.create!(
      url: "https://example.com",
      status: :failed,
      error_message: "Connection timeout"
    )

    get "/admin/sources/archive_status/#{archive_item.id}", as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "failed", body["status"]
    assert_equal "Connection timeout", body["error"]
  end

  test "archive_status returns processing status" do
    archive_item = ArchiveItem.create!(
      url: "https://example.com",
      status: :processing
    )

    get "/admin/sources/archive_status/#{archive_item.id}", as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "processing", body["status"]
  end

  test "archive_status returns 404 for non-existent item" do
    get "/admin/sources/archive_status/999999", as: :json

    assert_response :not_found
    body = response.parsed_body
    assert_equal "Archive item not found", body["error"]
  end
end
