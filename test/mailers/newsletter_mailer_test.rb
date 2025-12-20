require "test_helper"

class NewsletterMailerTest < ActionMailer::TestCase
  test "confirmation_email uses rails_api_url as base url" do
    subscriber = subscribers(:unconfirmed_subscriber)
    site_info = { title: "Frontend", url: "https://frontend.example.com" }

    with_env("RAILS_API_URL" => "https://api.example.com") do
      email = NewsletterMailer.confirmation_email(subscriber, site_info)

      expected_url = Rails.application.routes.url_helpers.confirm_subscription_url(
        token: subscriber.confirmation_token,
        host: "api.example.com",
        protocol: "https"
      )

      assert_includes email.text_part.body.decoded, expected_url
      assert_includes email.html_part.body.decoded, expected_url
      assert_not_includes email.text_part.body.decoded, "frontend.example.com"
      assert_not_includes email.html_part.body.decoded, "frontend.example.com"
    end
  end

  test "confirmation_email accepts rails_api_url without protocol" do
    subscriber = subscribers(:unconfirmed_subscriber)
    site_info = { title: "Frontend", url: "https://frontend.example.com" }

    with_env("RAILS_API_URL" => "api.example.com") do
      email = NewsletterMailer.confirmation_email(subscriber, site_info)

      expected_url = Rails.application.routes.url_helpers.confirm_subscription_url(
        token: subscriber.confirmation_token,
        host: "api.example.com",
        protocol: "https"
      )

      assert_includes email.text_part.body.decoded, expected_url
      assert_includes email.html_part.body.decoded, expected_url
    end
  end

  test "confirmation_email respects rails_api_url path prefix" do
    subscriber = subscribers(:unconfirmed_subscriber)
    site_info = { title: "Frontend", url: "https://frontend.example.com" }

    with_env("RAILS_API_URL" => "https://api.example.com/api") do
      email = NewsletterMailer.confirmation_email(subscriber, site_info)

      expected_url = Rails.application.routes.url_helpers.confirm_subscription_url(
        token: subscriber.confirmation_token,
        host: "api.example.com",
        protocol: "https",
        script_name: "/api"
      )

      assert_includes email.text_part.body.decoded, expected_url
      assert_includes email.html_part.body.decoded, expected_url
    end
  end

  private

  def with_env(env)
    previous = {}
    env.each do |key, value|
      previous[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
