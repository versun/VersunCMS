require "application_system_test_case"

class SubscriptionsTest < ApplicationSystemTestCase
  test "subscribing to newsletter" do
    visit root_path

    fill_in "Email", with: "newsubscriber@example.com"
    click_button "Subscribe"

    assert_text "Thank you for subscribing"
  end

  test "subscribing with invalid email" do
    visit root_path

    fill_in "Email", with: "invalid-email"
    click_button "Subscribe"

    assert_text "Email is invalid"
  end

  test "confirming subscription" do
    subscriber = subscribers(:unconfirmed_subscriber)

    visit confirm_subscription_path(token: subscriber.confirmation_token)

    assert_text "Subscription confirmed"
    subscriber.reload
    assert subscriber.confirmed?
  end

  test "unsubscribing from newsletter" do
    subscriber = subscribers(:confirmed_subscriber)

    visit unsubscribe_subscription_path(token: subscriber.unsubscribe_token)

    assert_text "You have been unsubscribed"
    subscriber.reload
    assert subscriber.unsubscribed?
  end
end
