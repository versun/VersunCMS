require "test_helper"

class Tools::BackupControllerTest < ActionDispatch::IntegrationTest
  setup do
    @backup_setting = backup_settings(:one)  # 假设你有一个备份设置的fixture
  end

  test "should get index" do
    get tools_backup_index_url
    assert_response :success
    assert_not_nil assigns(:backup_setting)
    assert_not_nil assigns(:backup_logs)
  end

  test "should create backup setting" do
    assert_difference("BackupSetting.count", 1) do
      post tools_backup_index_url, params: {
        backup_setting: {
          repository_url: "git@github.com:user/repo.git",
          branch_name: "main",
          git_name: "Test User",
          git_email: "test@example.com",
          auto_backup: true,
          backup_interval: 24
        }
      }
    end

    assert_redirected_to tools_backup_index_path
    assert_equal "Backup settings saved successfully.", flash[:notice]
  end

  test "should update backup setting" do
    patch tools_backup_url(@backup_setting), params: {
      backup_setting: {
        repository_url: "git@github.com:user/new-repo.git"
      }
    }
    assert_redirected_to tools_backup_index_path
    assert_equal "Backup settings saved successfully.", flash[:notice]
    @backup_setting.reload
    assert_equal "git@github.com:user/new-repo.git", @backup_setting.repository_url
  end

  test "should start backup process" do
    assert_enqueued_with(job: BackupJob) do
      post perform_backup_tools_backup_index_url
    end
    assert_redirected_to tools_backup_index_path
    assert_equal "Backup process started.", flash[:notice]
  end

  test "should get backup status" do
    get backup_status_tools_backup_index_url
    assert_response :success

    response_json = JSON.parse(response.body)
    assert_includes response_json.keys, "last_backup"
    assert_includes response_json.keys, "status"
    assert_includes response_json.keys, "message"
  end

  test "should regenerate ssh key pair" do
    old_public_key = @backup_setting.ssh_public_key

    post regenerate_ssh_key_tools_backup_index_url

    assert_redirected_to tools_backup_index_path
    assert_equal "SSH key pair regenerated successfully.", flash[:notice]

    @backup_setting.reload
    assert_not_equal old_public_key, @backup_setting.ssh_public_key
    assert_not_nil @backup_setting.ssh_private_key
  end

  test "should handle failed ssh key regeneration" do
    BackupSetting.any_instance.stubs(:update).returns(false)

    post regenerate_ssh_key_tools_backup_index_url

    assert_redirected_to tools_backup_index_path
    assert_equal "Failed to regenerate SSH key pair.", flash[:alert]
  end
end
