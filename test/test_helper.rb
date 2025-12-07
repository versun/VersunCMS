ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...

  # Helper method to create a user with authentication
  def create_user(user_name: "testuser", password: "password123")
    User.create!(
      user_name: user_name,
      password: password,
      password_confirmation: password
    )
  end

  # Helper method to sign in a user
  def sign_in(user)
    session = user.sessions.create!(
      user_agent: "Test Agent",
      ip_address: "127.0.0.1"
    )
    cookies.signed[:session_id] = session.id
    user
  end

  # Helper method to create a published article
  def create_published_article(attributes = {})
    default_attributes = {
      title: "Test Article",
      slug: "test-article-#{Time.current.to_i}",
      description: "Test description",
      status: :publish,
      content: "Test content"
    }
    Article.create!(default_attributes.merge(attributes))
  end

  # Helper method to create a draft article
  def create_draft_article(attributes = {})
    default_attributes = {
      title: "Draft Article",
      slug: "draft-article-#{Time.current.to_i}",
      description: "Draft description",
      status: :draft,
      content: "Draft content"
    }
    Article.create!(default_attributes.merge(attributes))
  end

  # Helper method to create a tag
  def create_tag(name: "test-tag", slug: nil)
    Tag.create!(
      name: name,
      slug: slug || name.parameterize
    )
  end

  # Helper method to create a subscriber
  def create_subscriber(email: "test@example.com", confirmed: true)
    subscriber = Subscriber.create!(
      email: email,
      confirmation_token: SecureRandom.urlsafe_base64(32),
      unsubscribe_token: SecureRandom.urlsafe_base64(32)
    )
    subscriber.update!(confirmed_at: Time.current) if confirmed
    subscriber
  end
end

class ActionDispatch::IntegrationTest
  # Helper method for authenticated requests
  def authenticated_request(method, path, user, params: {})
    # Create a session for the user
    session = user.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "Test Agent"
    )

    # Set session cookie
    cookies[:_session_id] = session.id.to_s

    # Make the request
    send(method, path, params: params)
  end
end

