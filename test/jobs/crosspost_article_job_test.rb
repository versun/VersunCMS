require "test_helper"

class CrosspostArticleJobTest < ActiveJob::TestCase
  fixtures :articles
  setup do
    @article = articles(:published_post_1)
  end

  test "文章跨平台发布到所有启用的平台" do
    # 设置文章的跨平台发布选项
    @article.update(
      crosspost_mastodon: true,
      crosspost_twitter: true,
      crosspost_bluesky: true
    )

    # 模拟各服务的返回URL
    mastodon_url = "https://mastodon.social/@user/123"
    twitter_url = "https://twitter.com/user/status/123"
    bluesky_url = "https://bsky.app/profile/user/post/123"

    # 模拟各服务的post方法
    MastodonService.any_instance.stubs(:post).returns(mastodon_url)
    TwitterService.any_instance.stubs(:post).returns(twitter_url)
    BlueskyService.any_instance.stubs(:post).returns(bluesky_url)

    # 执行任务
    CrosspostArticleJob.perform_now(@article.id)

    # 验证结果
    @article.reload
    assert_equal mastodon_url, @article.crosspost_urls["mastodon"]
    assert_equal twitter_url, @article.crosspost_urls["twitter"]
    assert_equal bluesky_url, @article.crosspost_urls["bluesky"]
  end

  test "仅发布到启用的平台" do
    # 只启用 Bluesky
    @article.update(
      crosspost_mastodon: false,
      crosspost_twitter: false,
      crosspost_bluesky: true
    )

    bluesky_url = "https://bsky.app/profile/user/post/123"
    BlueskyService.any_instance.stubs(:post).returns(bluesky_url)

    # 确保其他服务不会被调用
    MastodonService.any_instance.expects(:post).never
    TwitterService.any_instance.expects(:post).never

    CrosspostArticleJob.perform_now(@article.id)

    @article.reload
    assert_nil @article.crosspost_urls["mastodon"]
    assert_nil @article.crosspost_urls["twitter"]
    assert_equal bluesky_url, @article.crosspost_urls["bluesky"]
  end

  test "处理文章不存在的情况" do
    # 使用不存在的文章ID
    assert_nothing_raised do
      CrosspostArticleJob.perform_now(-1)
    end
  end

  test "处理服务发布失败的情况" do
    @article.update(crosspost_bluesky: true)

    # 模拟 Bluesky 发布失败
    BlueskyService.any_instance.stubs(:post).returns(nil)

    CrosspostArticleJob.perform_now(@article.id)

    @article.reload
    assert_empty @article.crosspost_urls
  end
end
