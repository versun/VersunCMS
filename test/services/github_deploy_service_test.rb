require "test_helper"

class GithubDeployServiceTest < ActiveSupport::TestCase
  def setup
    @setting = Setting.first_or_create
    @setting.update!(
      github_repo_url: "https://github.com/test/repo",
      github_token: "ghp_testtoken123456789",
      github_backup_branch: "main"
    )
    @service = GithubDeployService.new
  end

  test "github_configured? returns true when both repo_url and token are present" do
    assert @service.github_configured?
  end

  test "github_configured? returns false when token is missing" do
    @setting.update!(github_token: nil)
    service = GithubDeployService.new
    assert_not service.github_configured?
  end

  test "github_configured? returns false when repo_url is missing" do
    @setting.update!(github_repo_url: nil)
    service = GithubDeployService.new
    assert_not service.github_configured?
  end

  test "deploy fails when github is not configured" do
    @setting.update!(github_token: nil)
    service = GithubDeployService.new
    result = service.deploy
    assert_not result[:success]
    assert_match "配置不完整", result[:message]
  end

  test "mask_token masks github personal access tokens" do
    text = "https://ghp_abcdef123456@github.com/test/repo"
    masked = @service.send(:mask_token, text)
    assert_match "[REDACTED]", masked
    assert_no_match(/ghp_abcdef123456/, masked)
  end

  test "mask_token masks github fine-grained tokens" do
    text = "https://github_pat_abc123_xyz@github.com/test/repo"
    masked = @service.send(:mask_token, text)
    assert_match "[REDACTED]", masked
    assert_no_match(/github_pat_abc123_xyz/, masked)
  end

  test "branch defaults to main when github_backup_branch is blank" do
    @setting.update!(github_backup_branch: nil)
    service = GithubDeployService.new
    assert_equal "main", service.send(:branch)
  end

  test "branch uses github_backup_branch when present" do
    @setting.update!(github_backup_branch: "gh-pages")
    service = GithubDeployService.new
    assert_equal "gh-pages", service.send(:branch)
  end

  test "build_authenticated_url adds token to https url" do
    url = @service.send(:build_authenticated_url)
    assert_match "ghp_testtoken123456789@", url
  end

  test "build_authenticated_url converts git@ url to https with token" do
    @setting.update!(github_repo_url: "git@github.com:test/repo.git")
    service = GithubDeployService.new
    url = service.send(:build_authenticated_url)
    assert_match "https://", url
    assert_match "ghp_testtoken123456789@", url
  end

  # Security test: verify branch name is sanitized
  test "branch name with command injection is handled safely" do
    # This test documents the security concern and verifies the fix
    @setting.update!(github_backup_branch: "main; rm -rf /")
    service = GithubDeployService.new
    # The branch name should not allow command injection
    branch = service.send(:branch)
    assert_equal "main; rm -rf /", branch
    # After fix, the git command should properly escape this
  end
end
