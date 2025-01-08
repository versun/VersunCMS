# COPY from: https://t27duck.com/posts/17-a-bluesky-at-proto-api-example-in-ruby
class BlueskyService
  TOKEN_CACHE_KEY = :bluesky_token_data

  def initialize(article)
    @article = article
    @settings = Crosspost.bluesky
    return unless @settings.present?

    @username = @settings.access_token
    @password = @settings.access_token_secret
    @server_url = "https://bsky.social/xrpc" if @settings.server_url.blank?

    if (token_data = Rails.cache.read(TOKEN_CACHE_KEY))
      process_tokens(token_data)
    end
  end

  def verify(settings)
    return false if settings[:access_token].blank? || settings[:access_token_secret].blank?

    # Temporarily store the current credentials
    original_username = @username
    original_password = @password
    original_server_url = @server_url

    begin
      @username = settings[:access_token]
      @password = settings[:access_token_secret]
      @server_url = settings[:server_url]

      # Clear any existing token data
      @token = nil
      @token_expires_at = nil
      Rails.cache.delete(TOKEN_CACHE_KEY)

      # Attempt to generate new tokens with the provided credentials
      verify_tokens
      true
    rescue => e
      Rails.logger.error "Bluesky verification failed: #{e.class.name}"
      Rails.logger.error "Error message: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      false
    ensure
      # Restore the original credentials
      @username = original_username
      @password = original_password
      @server_url = original_server_url
    end
  end

  def post(article)
    return unless @settings&.enabled?

    content = build_content

    begin
      response = skeet(content)
      Rails.logger.info "Successfully posted article #{@article.title} to Bluesky"
      response
    rescue => e
      Rails.logger.error "Failed to post article #{@article.title} to Bluesky: #{e.message}"
      nil
    end
  end

  # Posts a new message (skeet) to the account and return the direct URL.
  def skeet(message)
    # Generate, refresh, or use an active token.
    verify_tokens

    # URLs and tags are not automatically parsed. Instead we have to manually
    # parse and set facets for each.
    # See: https://docs.bsky.app/docs/advanced-guides/post-richtext
    facets = link_facets(message)
    # facets += tag_facets(message)

    body = {
      repo: @user_did, collection: "app.bsky.feed.post",
      record: { text: message, createdAt: Time.now.iso8601, langs: [ "en" ], facets: facets }
    }
    response_body = post_request("#{@server_url}/com.atproto.repo.createRecord", body: body)

    # This is the full atproto URI
    # Ex: "at://did:plc:axbcdefg12345/app.bsky.feed.post/abcdefg12345"
    if response_body["uri"].present?
      "https://bsky.app/profile/#{@settings.access_token}/post/#{response_body["uri"].split('/').last}"
    end
  end

  # Given a atproto URI of a skeet, parse out the identifying information and remove it
  # from the account's timeline.
  def unskeet(skeet_uri)
    # Generate, refresh, or use an active token.
    verify_tokens

    did, nsid, record_key = skeet_uri.delete_prefix("at://").split("/")
    body = { repo: did, collection: nsid, rkey: record_key }
    post_request("#{@server_url}/com.atproto.repo.deleteRecord", body: body)
  end

  private

  def build_content
    post_url = build_post_url
    content_text = @article.description.present? ? @article.description : @article.content.body.to_plain_text
    max_content_length = 300 - post_url.length - 30

    "#{@article.title}\n#{content_text[0...max_content_length]}\n...\n\nRead more: #{post_url}"
  end

  def build_post_url
    Rails.application.routes.url_helpers.article_url(
      @article.slug,
      host: Setting.first.url.sub(%r{https?://}, "")
    )
  end

  def retrieve_server_token
    token_data = Rails.cache.read(TOKEN_CACHE_KEY)
    if token_data.present?
      process_tokens(token_data)
      @token
    else
      verify_tokens
      @token
    end
  end

  def link_facets(message)
    [].tap do |facets|
      matches = []
      message.scan(URI::RFC2396_PARSER.make_regexp([ "http", "https" ])) { matches << Regexp.last_match }
      matches.each do |match|
        start, stop = match.byteoffset(0)
        facets << {
          "index" => { "byteStart" => start, "byteEnd" => stop },
          "features" => [ { "uri" => match[0], "$type" => "app.bsky.richtext.facet#link" } ]
        }
      end
    end
  end

  def tag_facets(message)
    [].tap do |facets|
      matches = []
      message.scan(/(^|[^\w])(#[\w\-]+)/) { matches << Regexp.last_match }
      matches.each do |match|
        start, stop = match.byteoffset(2)
        facets << {
          "index" => { "byteStart" => start, "byteEnd" => stop },
          "features" => [ { "tag" => match[2].delete_prefix("#"), "$type" => "app.bsky.richtext.facet#tag" } ]
        }
      end
    end
  end

  # Makes a POST request to the API.
  def post_request(url, body: {}, auth_token: true, content_type: "application/json")
    uri = URI.parse(url)
    Rails.logger.info "POST request to URL:#{url} and URI:#{uri}"
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 4
    http.read_timeout = 4
    http.write_timeout = 4
    request = Net::HTTP::Post.new(uri.path)
    request["content-type"] = content_type

    # This allows the authorization token to:
    #   - Be sent using the currently stored token (true).
    #   - Not send when providing the username/password to generate the token (false).
    #   - Use a different token - like the refresh token (string).
    if auth_token
      token = auth_token.is_a?(String) ? auth_token : @token
      request["Authorization"] = "Bearer #{token}"
    end
    request.body = body.is_a?(Hash) ? body.to_json : body if body.present?
    response = http.request(request)
  raise "#{response.code} response - #{response.body}" unless response.code.to_s.start_with?("2")

    response.content_type == "application/json" ? JSON.parse(response.body) : response.body
  end

  # Generate tokens given an account identifier and app password.
  def generate_tokens
    body = { identifier: @username, password: @password }
    response_body = post_request("#{@server_url}/com.atproto.server.createSession", body: body, auth_token: false)

    process_tokens(response_body)
    store_token_data(response_body)
  end

  # Regenerates expired tokens with the refresh token.
  def perform_token_refresh
    response_body = post_request("#{@server_url}/com.atproto.server.refreshSession", auth_token: @renewal_token)

    process_tokens(response_body)
    store_token_data(response_body)
  end

  # Makes sure a token is set and the token has not expired.
  # If this is the first request, we'll generate the token.
  # If the token expired, we'll refresh it.
  def verify_tokens
    if @token.nil?
      generate_tokens
    elsif @token_expires_at < Time.now.utc + 60
      perform_token_refresh
    end
  end

  # Given the response body of generating or refreshing token, this pulls out
  # and stores the bits of information we care about.
  def process_tokens(response_body)
    @token = response_body["accessJwt"]
    @renewal_token = response_body["refreshJwt"]
    @user_did = response_body["did"]
    @token_expires_at = Time.at(JSON.parse(Base64.decode64(response_body["accessJwt"].split(".")[1]))["exp"]).utc
  end

  # Stores the token info for use later, else we'll have to generate the token
  # for every instance of this class.
  # Assumes the cached info is stored in the Rails cache store.
  def store_token_data(data)
    Rails.cache.write(TOKEN_CACHE_KEY, data)
  end
end
