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

end
