require "application_system_test_case"

class SubscriptionsTest < ApplicationSystemTestCase
  test "subscribing from the subscriptions page" do
    email = "subscriber-#{SecureRandom.hex(6)}@example.com"

    visit subscriptions_path
    fill_in "输入您的邮箱地址", with: email
    click_button "订阅"

    assert_current_path root_path
    assert_text "订阅成功！请检查您的邮箱并点击确认链接。"
  end

  test "confirming a subscription token" do
    subscriber = create_subscriber(email: "confirm-#{SecureRandom.hex(6)}@example.com", confirmed: false)

    visit confirm_subscription_path(token: subscriber.confirmation_token)

    assert_text "订阅确认成功"
    subscriber.reload
    assert subscriber.confirmed?
  end

  test "unsubscribing with a token" do
    subscriber = create_subscriber(email: "unsub-#{SecureRandom.hex(6)}@example.com", confirmed: true)

    visit unsubscribe_path(token: subscriber.unsubscribe_token)

    assert_text "取消订阅成功"
    subscriber.reload
    assert subscriber.unsubscribed?
  end
end
