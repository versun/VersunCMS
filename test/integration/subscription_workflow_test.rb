require "test_helper"

class SubscriptionWorkflowTest < ActionDispatch::IntegrationTest
  test "complete subscription workflow" do
    # Step 1: Subscribe
    assert_difference "Subscriber.count", 1 do
      post subscriptions_path, params: {
        subscriber: {
          email: "workflow@example.com"
        }
      }
    end
    
    subscriber = Subscriber.find_by(email: "workflow@example.com")
    assert_not_nil subscriber
    assert_not subscriber.confirmed?
    assert_not_nil subscriber.confirmation_token
    
    # Step 2: Confirm subscription
    get confirm_subscription_path(token: subscriber.confirmation_token)
    
    subscriber.reload
    assert subscriber.confirmed?
    assert subscriber.active?
    
    # Step 3: Unsubscribe
    get unsubscribe_subscription_path(token: subscriber.unsubscribe_token)
    
    subscriber.reload
    assert subscriber.unsubscribed?
    assert_not subscriber.active?
  end

  test "subscription with tags workflow" do
    tag1 = tags(:ruby)
    tag2 = tags(:rails)
    
    # Subscribe
    post subscriptions_path, params: {
      subscriber: {
        email: "tagged@example.com"
      }
    }
    
    subscriber = Subscriber.find_by(email: "tagged@example.com")
    
    # Confirm
    get confirm_subscription_path(token: subscriber.confirmation_token)
    subscriber.reload
    
    # Add tags (assuming there's an admin interface for this)
    # This would typically be done through an admin interface
    subscriber.tags << [tag1, tag2]
    
    assert_equal 2, subscriber.tags.count
    assert subscriber.subscribed_to_tag?(tag1)
    assert subscriber.subscribed_to_tag?(tag2)
    
    # Verify scope works
    subscribers_with_ruby = Subscriber.subscribed_to_tag(tag1)
    assert_includes subscribers_with_ruby, subscriber
  end

  test "duplicate subscription prevention" do
    existing_subscriber = subscribers(:confirmed_subscriber)
    
    # Try to subscribe with same email
    assert_no_difference "Subscriber.count" do
      post subscriptions_path, params: {
        subscriber: {
          email: existing_subscriber.email
        }
      }
    end
  end

  test "subscription confirmation with invalid token" do
    get confirm_subscription_path(token: "invalid-token-12345")
    assert_response :not_found
  end

  test "unsubscribe with invalid token" do
    get unsubscribe_subscription_path(token: "invalid-token-12345")
    assert_response :not_found
  end
end
