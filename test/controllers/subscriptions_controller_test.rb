require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @subscriber = subscribers(:confirmed_subscriber)
  end

  test "should respond to CORS preflight for subscriptions" do
    options subscriptions_path, headers: {
      "Origin" => "https://example.com",
      "Access-Control-Request-Method" => "POST",
      "Access-Control-Request-Headers" => "X-Requested-With, Accept"
    }

    assert_response :success
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Allow-Methods"], "POST"
  end

  test "should create subscription" do
    assert_difference "Subscriber.count", 1 do
      post subscriptions_path, params: {
        subscription: {
          email: "new@example.com"
        }
      }, as: :json
    end

    assert_response :success
  end

  test "should not create subscription with invalid email" do
    assert_no_difference "Subscriber.count" do
      post subscriptions_path, params: {
        subscription: {
          email: "invalid-email"
        }
      }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "should not create duplicate subscription" do
    assert_no_difference "Subscriber.count" do
      post subscriptions_path, params: {
        subscription: {
          email: @subscriber.email
        }
      }, as: :json
    end
    assert_response :success
  end

  test "should confirm subscription with valid token" do
    subscriber = subscribers(:unconfirmed_subscriber)

    get confirm_subscription_path(token: subscriber.confirmation_token)

    subscriber.reload
    assert subscriber.confirmed?
  end

  test "should not confirm subscription with invalid token" do
    get confirm_subscription_path(token: "invalid-token")
    assert_response :success
    assert_includes response.body, "无效的确认链接"
  end

  test "should unsubscribe with valid token" do
    subscriber = subscribers(:confirmed_subscriber)

    get unsubscribe_path(token: subscriber.unsubscribe_token)

    subscriber.reload
    assert subscriber.unsubscribed?
  end

  test "should not unsubscribe with invalid token" do
    get unsubscribe_path(token: "invalid-token")
    assert_response :success
    assert_includes response.body, "无效的取消订阅链接"
  end
end
