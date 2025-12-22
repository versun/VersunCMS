class Admin::GitIntegrationsController < Admin::BaseController
  def index
    GitIntegration.ensure_all_providers
    @integrations = GitIntegration.order(:provider)
  end

  def update
    provider = params[:id].to_s
    return head(:not_found) unless GitIntegration::PROVIDERS.include?(provider)

    @integration = GitIntegration.find_or_initialize_by(provider: provider)
    @integration.name ||= GitIntegration::PROVIDER_NAMES[provider]

    attrs = git_integration_params.to_h.with_indifferent_access
    attrs.delete(:access_token) if attrs[:access_token].blank?

    if @integration.update(attrs)
      ActivityLog.create!(
        action: "updated",
        target: "git_integration",
        level: :info,
        description: "更新 Git 集成设置: #{@integration.display_name}"
      )
      redirect_to admin_git_integrations_path, notice: "#{@integration.display_name} 设置已更新。"
    else
      ActivityLog.create!(
        action: "failed",
        target: "git_integration",
        level: :error,
        description: "更新 Git 集成设置失败: #{@integration.display_name} - #{@integration.errors.full_messages.join(', ')}"
      )
      redirect_to admin_git_integrations_path, alert: @integration.errors.full_messages.join(", ")
    end
  end

  def verify
    @provider = params[:id].to_s
    return head(:not_found) unless GitIntegration::PROVIDERS.include?(@provider)

    @message = ""
    @status = ""

    begin
      integration = GitIntegration.find_or_initialize_by(provider: @provider)
      integration.name ||= GitIntegration::PROVIDER_NAMES[@provider]

      submitted = params.fetch(:git_integration, {}).permit(:server_url, :access_token, :username)
      effective_access_token = submitted[:access_token].presence || integration.access_token
      effective_username = submitted[:username].presence || integration.username
      effective_server_url = submitted[:server_url].presence || integration.server_url

      integration.assign_attributes(
        server_url: effective_server_url,
        username: effective_username,
        access_token: effective_access_token
      )

      raise "Access token is required" if integration.access_token.blank?
      raise "Username is required" if integration.provider == "bitbucket" && integration.username.blank?

      # Test connection based on provider
      result = test_connection(integration)

      if result[:success]
        @status = "success"
        @message = result[:message] || "连接验证成功！"
      else
        @status = "error"
        @message = result[:error]
      end
    rescue => e
      @status = "error"
      @message = "错误: #{e.message}"
    end

    respond_to do |format|
      format.turbo_stream
      format.json { render json: { status: @status, message: @message } }
    end
  end

  private

  def git_integration_params
    params.expect(git_integration: [ :name, :server_url, :username, :access_token, :enabled ])
  end

  def test_connection(integration)
    require "net/http"
    require "json"
    require "ipaddr"

    case integration.provider
    when "github"
      test_github(integration)
    when "gitlab"
      test_gitlab(integration)
    when "gitea"
      test_gitea(integration)
    when "codeberg"
      test_codeberg(integration)
    when "bitbucket"
      test_bitbucket(integration)
    else
      { success: false, error: "未知的提供商: #{integration.provider}" }
    end
  rescue => e
    { success: false, error: e.message }
  end

  def test_github(integration)
    uri = URI("https://api.github.com/user")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{integration.access_token}"
    request["Accept"] = "application/vnd.github+json"
    request["User-Agent"] = "Rables"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      user = JSON.parse(response.body)
      { success: true, message: "已连接到 GitHub，用户: #{user['login']}" }
    else
      { success: false, error: "GitHub API 错误: #{response.code} - #{response.body}" }
    end
  end

  def test_gitlab(integration)
    base_url = integration.server_base_url || "https://gitlab.com"
    validate_outbound_base_url!(base_url) if integration.server_url.present?
    uri = URI("#{base_url}/api/v4/user")
    request = Net::HTTP::Get.new(uri)
    request["PRIVATE-TOKEN"] = integration.access_token

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      user = JSON.parse(response.body)
      { success: true, message: "已连接到 GitLab，用户: #{user['username']}" }
    else
      { success: false, error: "GitLab API 错误: #{response.code} - #{response.body}" }
    end
  end

  def test_gitea(integration)
    base_url = integration.server_base_url
    return { success: false, error: "Gitea 需要提供服务器 URL" } if base_url.blank?
    validate_outbound_base_url!(base_url)

    uri = URI("#{base_url}/api/v1/user")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "token #{integration.access_token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      user = JSON.parse(response.body)
      { success: true, message: "已连接到 Gitea，用户: #{user['login'] || user['username']}" }
    else
      { success: false, error: "Gitea API 错误: #{response.code} - #{response.body}" }
    end
  end

  def test_codeberg(integration)
    uri = URI("https://codeberg.org/api/v1/user")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "token #{integration.access_token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      user = JSON.parse(response.body)
      { success: true, message: "已连接到 Codeberg，用户: #{user['login'] || user['username']}" }
    else
      { success: false, error: "Codeberg API 错误: #{response.code} - #{response.body}" }
    end
  end

  def test_bitbucket(integration)
    uri = URI("https://api.bitbucket.org/2.0/user")
    request = Net::HTTP::Get.new(uri)
    request.basic_auth(integration.username, integration.access_token)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      user = JSON.parse(response.body)
      { success: true, message: "已连接到 Bitbucket，用户: #{user['username'] || user['display_name']}" }
    else
      { success: false, error: "Bitbucket API 错误: #{response.code} - #{response.body}" }
    end
  end

  def validate_outbound_base_url!(base_url)
    uri = URI.parse(base_url.to_s)
    raise "Server URL must be http(s)" unless uri.is_a?(URI::HTTP) && uri.host.present?
    raise "Server URL must not include credentials" if uri.userinfo.present?

    host = uri.host.to_s.downcase

    disallowed_hosts = %w[localhost].freeze
    raise "Server URL is not allowed" if disallowed_hosts.include?(host) || host.end_with?(".localhost")

    # Prevent common SSRF footguns. For self-hosted instances on private networks,
    # set ALLOW_PRIVATE_GIT_SERVER_URLS=1 to permit private/ULA targets.
    ips = resolved_ips_for_host(host)
    ips.each do |ip|
      reason = outbound_ip_disallowed_reason(ip)
      next if reason.blank?

      raise reason
    end
  end

  def resolved_ips_for_host(host)
    require "resolv"

    begin
      return [ IPAddr.new(host) ]
    rescue IPAddr::InvalidAddressError
      # Hostname
    end

    addresses = Resolv.getaddresses(host)
    raise "Server URL host could not be resolved" if addresses.empty?

    addresses.map { |addr| IPAddr.new(addr) }
  end

  def outbound_ip_disallowed_reason(ip)
    return "Server URL is not allowed (loopback/link-local/multicast/unspecified)" if ip.loopback? || ip.link_local? || ip.multicast? || ip.unspecified?

    allow_private = ActiveModel::Type::Boolean.new.cast(ENV.fetch("ALLOW_PRIVATE_GIT_SERVER_URLS", "0"))
    return if allow_private
    return if !ip.private?

    "Server URL is not allowed (private network). Set ALLOW_PRIVATE_GIT_SERVER_URLS=1 to allow."
  end
end
