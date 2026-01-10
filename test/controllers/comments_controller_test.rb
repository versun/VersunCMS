require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  def captcha_params(a: 3, b: 4, op: "+", answer: nil)
    expected = op == "+" ? (a + b) : (a - b)
    { captcha: { a:, b:, op:, answer: (answer || expected).to_s } }
  end

  test "should reject comment without captcha" do
    article = articles(:published_article)

    assert_no_difference "Comment.count" do
      post comments_path(article_id: article.slug), params: {
        comment: {
          author_name: "Spammer",
          content: "Buy now!"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal false, response.parsed_body["success"]
  end

  test "should create comment with valid captcha" do
    article = articles(:published_article)

    assert_difference "Comment.count", 1 do
      post comments_path(article_id: article.slug), params: {
        comment: {
          author_name: "Alice",
          content: "Nice post!"
        }
      }.merge(captcha_params), as: :json
    end

    assert_response :created
    assert_equal true, response.parsed_body["success"]
  end

  test "shows success message after html submit" do
    article = articles(:published_article)
    article.update!(comment: true)

    assert_difference "Comment.count", 1 do
      post comments_path(article_id: article.slug), params: {
        comment: {
          author_name: "Alice",
          content: "Nice post!"
        }
      }.merge(captcha_params)
    end

    assert_redirected_to article_path(article)
    follow_redirect!
    assert_response :success
    # Success message is now inline in the comment form, not in flash notice
    assert_select ".flash-notice", false
    assert_select ".comment-form .comment-success-message", /Your comment will be reviewed/
  end

  test "html submit with invalid captcha redirects with alert" do
    article = articles(:published_article)

    assert_no_difference "Comment.count" do
      post comments_path(article_id: article.slug), params: {
        comment: {
          author_name: "Alice",
          content: "Nice post!"
        },
        captcha: { a: "1", b: "1", op: "+", answer: "" }
      }
    end

    assert_redirected_to article_path(article)
    assert_match "验证失败", flash[:alert]
  end

  test "creates comment for page with valid captcha" do
    page = pages(:published_page)

    assert_difference "Comment.count", 1 do
      post comments_path(page_id: page.slug), params: {
        comment: {
          author_name: "Page User",
          content: "Nice page!"
        }
      }.merge(captcha_params), as: :json
    end

    assert_response :created
  end

  test "invalid comment returns unprocessable json" do
    article = articles(:published_article)

    assert_no_difference "Comment.count" do
      post comments_path(article_id: article.slug), params: {
        comment: {
          author_name: "",
          content: ""
        }
      }.merge(captcha_params), as: :json
    end

    assert_response :unprocessable_entity
    assert_equal false, response.parsed_body["success"]
  end

  test "xhr html request returns json on success" do
    article = articles(:published_article)

    assert_difference "Comment.count", 1 do
      post comments_path(article_id: article.slug), params: {
        comment: {
          author_name: "XHR User",
          content: "XHR comment"
        }
      }.merge(captcha_params), headers: { "X-Requested-With" => "XMLHttpRequest" }
    end

    assert_response :created
    assert_includes response.body, "评论已提交"
  end

  test "unexpected error returns json error" do
    article = articles(:published_article)

    Comment.class_eval do
      alias_method :original_save, :save
      def save(*)
        raise "boom"
      end
    end

    post comments_path(article_id: article.slug), params: {
      comment: {
        author_name: "Crash",
        content: "Crash"
      }
    }.merge(captcha_params), as: :json

    assert_response :internal_server_error
    assert_includes response.body, "提交评论时发生错误"
  ensure
    Comment.class_eval do
      alias_method :save, :original_save
      remove_method :original_save
    end
  end

  test "xhr html request returns json on captcha failure" do
    article = articles(:published_article)

    post comments_path(article_id: article.slug), params: {
      comment: {
        author_name: "XHR User",
        content: "XHR comment"
      },
      captcha: { a: "1", b: "1", op: "+", answer: "" }
    }, headers: { "X-Requested-With" => "XMLHttpRequest" }

    assert_response :unprocessable_entity
    assert_includes response.body, "验证失败"
  end

  test "html invalid comment redirects with alert" do
    article = articles(:published_article)

    assert_no_difference "Comment.count" do
      post comments_path(article_id: article.slug), params: {
        comment: {
          author_name: "",
          content: ""
        }
      }.merge(captcha_params)
    end

    assert_redirected_to article_path(article)
    assert_match "提交评论时出错", flash[:alert]
  end

  test "html comment on page redirects to page" do
    page = pages(:published_page)

    assert_difference "Comment.count", 1 do
      post comments_path(page_id: page.slug), params: {
        comment: {
          author_name: "Page Html",
          content: "Nice page!"
        }
      }.merge(captcha_params)
    end

    assert_redirected_to page_path(page)
  end

  test "xhr html request returns json on validation error" do
    article = articles(:published_article)

    assert_no_difference "Comment.count" do
      post comments_path(article_id: article.slug), params: {
        comment: {
          author_name: "",
          content: ""
        }
      }.merge(captcha_params), headers: { "X-Requested-With" => "XMLHttpRequest" }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "提交评论时出错"
  end

  test "rescues record not found during build" do
    article = articles(:published_article)

    original_comments = Article.instance_method(:comments)
    Article.define_method(:comments) { raise ActiveRecord::RecordNotFound }

    post comments_path(article_id: article.slug), params: {
      comment: {
        author_name: "Ghost",
        content: "Missing"
      }
    }.merge(captcha_params), as: :json

    assert_response :not_found
    assert_includes response.body, "文章或页面未找到"
  ensure
    Article.define_method(:comments, original_comments)
  end

  test "xhr html record not found returns json" do
    article = articles(:published_article)
    original_comments = Article.instance_method(:comments)
    Article.define_method(:comments) { raise ActiveRecord::RecordNotFound }

    post comments_path(article_id: article.slug), params: {
      comment: {
        author_name: "Ghost",
        content: "Missing"
      }
    }.merge(captcha_params), headers: { "X-Requested-With" => "XMLHttpRequest" }

    assert_response :not_found
    assert_includes response.body, "文章或页面未找到"
  ensure
    Article.define_method(:comments, original_comments)
  end

  test "html record not found redirects to root" do
    article = articles(:published_article)
    original_comments = Article.instance_method(:comments)
    Article.define_method(:comments) { raise ActiveRecord::RecordNotFound }

    post comments_path(article_id: article.slug), params: {
      comment: {
        author_name: "Ghost",
        content: "Missing"
      }
    }.merge(captcha_params)

    assert_redirected_to root_path
  ensure
    Article.define_method(:comments, original_comments)
  end
end
