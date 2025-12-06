require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @subscriber = subscribers(:confirmed_subscriber)
  end

  test "should create subscription" do
    assert_difference "Subscriber.count", 1 do
      post subscriptions_path, params: {
        subscriber: {
          email: "new@example.com"
        }
      }
    end
    
    assert_response :success
  end

  test "should not create subscription with invalid email" do
    assert_no_difference "Subscriber.count" do
      post subscriptions_path, params: {
        subscriber: {
          email: "invalid-email"
        }
      }
    end
  end

  test "should not create duplicate subscription" do
    assert_no_difference "Subscriber.count" do
      post subscriptions_path, params: {
        subscriber: {
          email: @subscriber.email
        }
      }
    end
  end

  test "should confirm subscription with valid token" do
    subscriber = subscribers(:unconfirmed_subscriber)
    
    get confirm_subscription_path(token: subscriber.confirmation_token)
    
    subscriber.reload
    assert subscriber.confirmed?
  end

  test "should not confirm subscription with invalid token" do
    get confirm_subscription_path(token: "invalid-token")
    assert_response :not_found
  end

  test "should unsubscribe with valid token" do
    subscriber = subscribers(:confirmed_subscriber)
    
    get unsubscribe_subscription_path(token: subscriber.unsubscribe_token)
    
    subscriber.reload
    assert subscriber.unsubscribed?
  end

  test "should not unsubscribe with invalid token" do
    get unsubscribe_subscription_path(token: "invalid-token")
    assert_response :not_found
  end
end
