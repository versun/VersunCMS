require "test_helper"
require "minitest/mock"

class InternetArchiveServiceTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, keyword_init: true)

  setup do
    @settings = ArchiveSetting.instance
    @settings.update!(
      ia_access_key: nil,
      ia_secret_key: nil
    )
  end

  test "configured? returns false when credentials are missing" do
    service = InternetArchiveService.new

    assert_not service.configured?
  end

  test "configured? returns true when credentials are present" do
    @settings.update!(
      ia_access_key: "test_access_key",
      ia_secret_key: "test_secret_key"
    )

    service = InternetArchiveService.new

    assert service.configured?
  end

  test "verify returns error when not configured" do
    service = InternetArchiveService.new
    result = service.verify

    assert_equal "Internet Archive credentials not configured", result[:error]
  end

  test "upload_html raises error when not configured" do
    service = InternetArchiveService.new

    assert_raises InternetArchiveService::UploadError do
      service.upload_html("/tmp/test.html", item_name: "test-item")
    end
  end

  test "upload_html raises error when file not found" do
    @settings.update!(
      ia_access_key: "test_access_key",
      ia_secret_key: "test_secret_key"
    )

    service = InternetArchiveService.new

    assert_raises InternetArchiveService::UploadError do
      service.upload_html("/nonexistent/file.html", item_name: "test-item")
    end
  end

  test "verify returns error for invalid access key" do
    @settings.update!(
      ia_access_key: "invalid_key",
      ia_secret_key: "test_secret_key"
    )

    # Stub the HTTP response for PUT request
    mock_response = Minitest::Mock.new
    mock_response.expect(:body, "<Error><Code>InvalidAccessKeyId</Code></Error>")
    mock_response.expect(:code, "403")

    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [ true ])
    mock_http.expect(:open_timeout=, nil, [ 10 ])
    mock_http.expect(:read_timeout=, nil, [ 10 ])
    mock_http.expect(:request, mock_response) do |request|
      request.is_a?(Net::HTTP::Put) &&
        request.path.end_with?("/_verify_credentials.txt") &&
        request["Authorization"] == "LOW invalid_key:test_secret_key" &&
        request["Content-Type"] == "text/plain" &&
        request.body == "verify"
    end

    Net::HTTP.stub(:new, mock_http) do
      service = InternetArchiveService.new
      result = service.verify

      assert_equal "Access Key 无效", result[:error]
    end
  end

  test "verify returns error for invalid secret key" do
    @settings.update!(
      ia_access_key: "test_access_key",
      ia_secret_key: "invalid_secret"
    )

    mock_response = Minitest::Mock.new
    mock_response.expect(:body, "<Error><Code>SignatureDoesNotMatch</Code></Error>")
    mock_response.expect(:code, "403")

    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [ true ])
    mock_http.expect(:open_timeout=, nil, [ 10 ])
    mock_http.expect(:read_timeout=, nil, [ 10 ])
    mock_http.expect(:request, mock_response) do |request|
      request.is_a?(Net::HTTP::Put) &&
        request.path.end_with?("/_verify_credentials.txt") &&
        request["Authorization"] == "LOW test_access_key:invalid_secret" &&
        request["Content-Type"] == "text/plain" &&
        request.body == "verify"
    end

    Net::HTTP.stub(:new, mock_http) do
      service = InternetArchiveService.new
      result = service.verify

      assert_equal "Secret Key 无效", result[:error]
    end
  end

  test "verify returns success for valid credentials" do
    @settings.update!(
      ia_access_key: "valid_access_key",
      ia_secret_key: "valid_secret_key"
    )

    mock_response = Minitest::Mock.new
    mock_response.expect(:body, "")
    mock_response.expect(:code, "200")

    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [ true ])
    mock_http.expect(:open_timeout=, nil, [ 10 ])
    mock_http.expect(:read_timeout=, nil, [ 10 ])
    mock_http.expect(:request, mock_response) do |request|
      request.is_a?(Net::HTTP::Put) &&
        request.path.end_with?("/_verify_credentials.txt") &&
        request["Authorization"] == "LOW valid_access_key:valid_secret_key" &&
        request["Content-Type"] == "text/plain" &&
        request.body == "verify"
    end

    Net::HTTP.stub(:new, mock_http) do
      service = InternetArchiveService.new
      result = service.verify

      assert result[:success]
    end
  end

  test "upload_to_s3 stops retrying after max_retries on 429" do
    @settings.update!(
      ia_access_key: "test_access_key",
      ia_secret_key: "test_secret_key"
    )

    response = FakeResponse.new(code: "429", body: "rate limited")
    fake_http = Class.new do
      attr_reader :request_count

      def initialize(response:, max_requests:)
        @response = response
        @max_requests = max_requests
        @request_count = 0
      end

      def use_ssl=(_value); end
      def open_timeout=(_value); end
      def read_timeout=(_value); end

      def request(_request)
        @request_count += 1
        raise "too many requests" if @request_count > @max_requests
        @response
      end
    end.new(response: response, max_requests: 6)

    service = InternetArchiveService.new

    Net::HTTP.stub(:new, fake_http) do
      service.stub(:sleep, nil) do
        error = assert_raises(InternetArchiveService::UploadError) do
          service.send(
            :upload_to_s3,
            item_name: "test-item",
            filename: "test.html",
            content: "<html></html>",
            title: "Test",
            max_retries: 3
          )
        end

        assert_match(/Rate limit exceeded after 3 retries/, error.message)
        assert_equal 4, fake_http.request_count
      end
    end
  end
end
