require "net/http"
require "json"
require "nokogiri"

class Admin::SourcesController < Admin::BaseController
  # POST /admin/sources/fetch_twitter
  # Fetch tweet content for source reference
  def fetch_twitter
    url = params[:url]

    if url.blank?
      render json: { error: "URL is required" }, status: :unprocessable_entity
      return
    end

    unless twitter_url?(url)
      render json: { error: "Not a valid Twitter/X URL" }, status: :unprocessable_entity
      return
    end

    result = fetch_twitter_content(url)

    if result
      render json: {
        success: true,
        author: result[:author],
        content: result[:content]
      }
    else
      render json: { error: "Failed to fetch tweet content" }, status: :service_unavailable
    end
  end

  # POST /admin/sources/archive
  # Archive a URL via single-file-cli and return an archive URL to store in source_archive_url
  def archive
    url = params[:url].to_s.strip

    if url.blank?
      render json: { error: "URL is required" }, status: :unprocessable_entity
      return
    end

    begin
      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        render json: { error: "URL must be HTTP(S)" }, status: :unprocessable_entity
        return
      end
    rescue URI::InvalidURIError
      render json: { error: "Invalid URL format" }, status: :unprocessable_entity
      return
    end

    settings = ArchiveSetting.instance
    unless settings.enabled? && settings.configured?
      render json: { error: "Archive is not configured" }, status: :unprocessable_entity
      return
    end

    archive_item = ArchiveItem.find_or_initialize_by(url: ArchiveItem.normalize_url(url))

    if archive_item.completed? && archive_item.file_path.present?
      archived_url = build_repo_file_url(archive_item.file_path, settings)
      if archived_url.blank?
        render json: { error: "Archived file exists but public URL could not be generated" }, status: :unprocessable_entity
        return
      end

      render json: { success: true, archived_url: archived_url }
      return
    end

    archive_item.status = :pending
    archive_item.error_message = nil
    archive_item.save!

    # Queue the archive job asynchronously
    ArchiveUrlJob.perform_later(archive_item.id)

    render json: { success: true, archive_item_id: archive_item.id, status: "pending" }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /admin/sources/archive_status/:id
  # Check archive job status and return result when complete
  def archive_status
    archive_item = ArchiveItem.find_by(id: params[:id])

    unless archive_item
      render json: { error: "Archive item not found" }, status: :not_found
      return
    end

    case archive_item.status
    when "completed"
      settings = ArchiveSetting.instance
      archived_url = build_repo_file_url(archive_item.file_path, settings)
      if archived_url.blank?
        render json: { status: "failed", error: "Archived file exists but public URL could not be generated" }
      else
        render json: { status: "completed", archived_url: archived_url }
      end
    when "failed"
      render json: { status: "failed", error: archive_item.error_message || "Archive failed" }
    else
      render json: { status: archive_item.status }
    end
  end

  private

  def twitter_url?(url)
    uri = URI.parse(url)
    host = uri.host.to_s.downcase
    %w[twitter.com www.twitter.com x.com www.x.com].include?(host)
  rescue URI::InvalidURIError
    false
  end

  def fetch_twitter_content(tweet_url)
    oembed_url = "https://publish.twitter.com/oembed"
    uri = URI(oembed_url)
    uri.query = URI.encode_www_form(url: tweet_url, omit_script: true, dnt: true)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      html = data["html"]

      doc = Nokogiri::HTML::DocumentFragment.parse(html)
      text = doc.css("p").map(&:text).join(" ").strip

      author_name = data["author_name"]
      content = text.presence || ""
      content = content[0, 250] if content.length > 250

      { author: author_name, content: content }
    else
      nil
    end
  rescue => e
    Rails.logger.error "Failed to fetch twitter content: #{e.message}"
    nil
  end

  def build_repo_file_url(file_path, settings)
    file_path = file_path.to_s.strip
    return nil if file_path.blank?

    branch = settings.branch.presence || "main"

    repo_url = settings.repo_url.to_s.strip
    git_integration = settings.git_integration
    return nil if git_integration.blank?

    provider = git_integration.provider.to_s
    server_base = git_integration.server_base_url.to_s.delete_suffix("/")

    owner, repo = extract_owner_repo(repo_url, server_base)
    return nil if owner.blank? || repo.blank?

    case provider
    when "github"
      "https://raw.githubusercontent.com/#{owner}/#{repo}/#{branch}/#{file_path}"
    when "gitlab"
      base = server_base.presence || "https://gitlab.com"
      "#{base}/#{owner}/#{repo}/-/raw/#{branch}/#{file_path}"
    when "gitea", "codeberg"
      return nil if server_base.blank?
      "#{server_base}/#{owner}/#{repo}/raw/branch/#{branch}/#{file_path}"
    when "bitbucket"
      "https://bitbucket.org/#{owner}/#{repo}/raw/#{branch}/#{file_path}"
    else
      nil
    end
  end

  def extract_owner_repo(repo_url, server_base)
    repo_url = repo_url.to_s.strip
    server_base = server_base.to_s.strip

    # git@github.com:owner/repo.git -> owner/repo.git
    if repo_url.start_with?("git@") && repo_url.include?(":")
      path = repo_url.split(":", 2).last.to_s
      return extract_owner_repo_from_path(path)
    end

    # owner/repo or owner/repo.git
    if repo_url.match?(%r{\A[^/]+/[^/]+\z})
      return extract_owner_repo_from_path(repo_url)
    end

    uri = URI.parse(repo_url)
    path = uri.path.to_s.delete_prefix("/")
    extract_owner_repo_from_path(path)
  rescue URI::InvalidURIError
    nil
  end

  def extract_owner_repo_from_path(path)
    parts = path.to_s.split("/").reject(&:blank?)
    return nil if parts.length < 2

    repo = parts.last.to_s.delete_suffix(".git")
    owner = parts[0..-2].join("/")
    [ owner, repo ]
  end
end
