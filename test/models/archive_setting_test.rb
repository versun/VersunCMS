require "test_helper"

class ArchiveSettingTest < ActiveSupport::TestCase
  test "requires git integration when enabled" do
    setting = ArchiveSetting.new(
      enabled: true,
      repo_url: "https://github.com/example/archive.git",
      branch: "main"
    )

    assert_not setting.valid?
    assert_includes setting.errors[:git_integration], "must be enabled and configured"
  end

  test "allows disabled without git integration" do
    setting = ArchiveSetting.new(enabled: false, branch: "main")
    assert setting.valid?
  end

  test "allows enabled with configured git integration" do
    setting = ArchiveSetting.new(
      enabled: true,
      repo_url: "https://github.com/example/archive.git",
      branch: "main",
      git_integration: git_integrations(:github)
    )

    assert setting.valid?
  end
end
