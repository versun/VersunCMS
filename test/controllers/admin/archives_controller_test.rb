require "test_helper"

class Admin::ArchivesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:admin)
    sign_in(@user)
  end

  test "create normalizes URL before lookup to avoid duplicates" do
    ArchiveItem.create!(url: "https://example.com", status: :completed)

    assert_no_difference "ArchiveItem.count" do
      assert_no_enqueued_jobs do
        post admin_archives_path, params: { url: "example.com" }
      end
    end

    assert_redirected_to admin_archives_path
    assert_equal "该 URL 已归档", flash[:alert]
  end

  test "create finds existing failed item when scheme-less URL is submitted" do
    archive_item = ArchiveItem.create!(url: "https://example.com", status: :failed)

    assert_no_difference "ArchiveItem.count" do
      assert_enqueued_with(job: ArchiveUrlJob, args: [ archive_item.id ]) do
        post admin_archives_path, params: { url: "example.com" }
      end
    end

    assert_redirected_to admin_archives_path
    assert_equal "URL 已加入归档队列", flash[:notice]
    assert archive_item.reload.pending?
  end
end
