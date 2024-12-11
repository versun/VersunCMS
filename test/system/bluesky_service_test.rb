require "application_system_test_case"
require "active_support/testing/assertions"
require "minitest/autorun"

class BlueskyServiceTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::Assertions
  fixtures :articles, :crosspost_settings
  setup do
    @article = articles(:published_post_1)
    @settings = crosspost_settings(:bluesky)
    Rails.cache.clear
  end

  test "验证 Bluesky 凭据" do
    service = BlueskyService.new(@article)

    # 测试有效凭据
    assert service.verify({
      access_token: "valid_username",
      access_token_secret: "valid_password",
      server_url: "https://bsky.social/xrpc"
    })

    # 测试无效凭据
    assert_not service.verify({
      access_token: "",
      access_token_secret: "",
      server_url: ""
    })
  end

  # test "发布文章到 Bluesky" do
  #   service = BlueskyService.new(@article)

  #   # 模拟成功发布
  #   response_url = "https://bsky.app/profile/test_user/post/123"
  #   service.stub :skeet, response_url do
  #     assert_equal response_url, service.post(@article)
  #   end

  #   # 验证文章更新
  #   @article.reload
  #   assert_includes @article.crosspost_urls, "bluesky"
  #   assert_equal response_url, @article.crosspost_urls["bluesky"]
  # end

  test "发布文章到 Bluesky" do
    service = BlueskyService.new(@article)
    response_url = "https://bsky.app/profile/test_user/post/123"

    # 使用Minitest::Mock可以更好地验证方法调用
    mock_service = Minitest::Mock.new
    mock_service.expect(:post, response_url, [ @article ])

    BlueskyService.stub :new, mock_service do
      result = service.post(@article)
      assert_equal response_url, result
      mock_service.verify
    end
  end


  test "处理发布失败情况" do
    service = BlueskyService.new(@article)

    # 模拟发布失败
    service.stub :skeet, -> { raise StandardError.new("API error") } do
      assert_nil service.post(@article)
    end

    # 验证文章状态
    @article.reload
    assert_not_includes @article.crosspost_urls, "bluesky"
  end
end
