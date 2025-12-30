require "open3"
require "fileutils"
require "json"
require "net/http"
require "tempfile"
require "tmpdir"
require "timeout"

class SingleFileArchiveService
  class ArchiveError < StandardError; end
  class SingleFileNotFoundError < ArchiveError; end
  class BrowserNotFoundError < ArchiveError; end
  class GitOperationError < ArchiveError; end

  DEFAULT_SINGLE_FILE_CLI = Rails.root.join("bin", Gem.win_platform? ? "single-file.exe" : "single-file").to_s
  SINGLE_FILE_CLI = ENV["SINGLE_FILE_CLI_PATH"].presence ||
    DEFAULT_SINGLE_FILE_CLI

  DEFAULT_CHROMIUM_DIR = Rails.root.join("bin", "chromium").to_s
  CHROME_FOR_TESTING_LKG_URL =
    URI("https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json")
  SINGLE_FILE_TIMEOUT_SECONDS = 120

  def initialize
    @settings = ArchiveSetting.instance
  end

  def configured?
    @settings.configured?
  end

  def archive_url(archive_item)
    raise ArchiveError, "Archive settings not configured" unless configured?

    validate_single_file_cli!

    Dir.mktmpdir("rables_archive") do |tmpdir|
      # Step 1: Run single-file-cli to archive the URL
      html_file = archive_with_single_file(archive_item.url, tmpdir)

      # Step 2: Clone the repo, add file, commit and push
      file_path = push_to_git(html_file, archive_item, tmpdir)

      # Step 3: Upload to Internet Archive if enabled
      ia_result = submit_to_archive_org(html_file, archive_item)

      # Return file info
      {
        file_path: file_path,
        file_size: File.size(html_file),
        ia_url: ia_result&.dig(:file_url)
      }
    end
  end

  def regenerate_index!
    raise ArchiveError, "Archive settings not configured" unless configured?

    Dir.mktmpdir("rables_archive_index") do |tmpdir|
      regenerate_index(tmpdir)
    end
  end

  def submit_to_archive_org(html_file, archive_item)
    return unless @settings.auto_submit_to_archive_org?

    service = InternetArchiveService.new
    return unless service.configured?

    # Generate a unique item name for Internet Archive
    item_name = generate_ia_item_name(archive_item.url)

    service.upload_html(
      html_file,
      item_name: item_name,
      title: archive_item.title || archive_item.url
    )
  rescue InternetArchiveService::UploadError => e
    Rails.logger.error "[SingleFileArchiveService] Failed to upload to Internet Archive: #{e.message}"
    nil
  end

  def validate_single_file_cli!
    stdout, stderr, status = Open3.capture3(SINGLE_FILE_CLI, "--version")
    return if status.success?

    details = safe_utf8(stderr).presence || safe_utf8(stdout)
    try_auto_install_single_file_cli!(original_error: details)
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOEXEC
    try_auto_install_single_file_cli!(original_error: $!.message)
  end

  private

  def safe_utf8(text)
    return "" if text.nil?

    text = text.to_s
    return text if text.encoding == Encoding::UTF_8 && text.valid_encoding?

    text = text.dup
    text.force_encoding(Encoding::UTF_8)
    text.scrub("�")
  end

  def try_auto_install_single_file_cli!(original_error:)
    raise single_file_not_found_error(original_error) unless auto_install_single_file_cli?

    install_single_file_cli!

    stdout, stderr, status = Open3.capture3(SINGLE_FILE_CLI, "--version")
    return if status.success?

    details = safe_utf8(stderr).presence || safe_utf8(stdout)
    raise single_file_not_found_error(details.presence || safe_utf8(original_error))
  end

  def auto_install_single_file_cli?
    return false if ENV["SINGLE_FILE_AUTO_INSTALL"].to_s.strip == "0"
    SINGLE_FILE_CLI == DEFAULT_SINGLE_FILE_CLI
  end

  def install_single_file_cli!
    FileUtils.mkdir_p(File.dirname(DEFAULT_SINGLE_FILE_CLI))

    lock_path = "#{DEFAULT_SINGLE_FILE_CLI}.install.lock"
    File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock_file|
      lock_file.flock(File::LOCK_EX)

      return if valid_single_file_cli_installed?

      if File.exist?(DEFAULT_SINGLE_FILE_CLI) && !File.executable?(DEFAULT_SINGLE_FILE_CLI)
        FileUtils.chmod(0o755, DEFAULT_SINGLE_FILE_CLI)
        return if valid_single_file_cli_installed?
      end

      Rails.logger.info "[SingleFileArchiveService] Installing single-file-cli to #{DEFAULT_SINGLE_FILE_CLI}"

      download_url = fetch_single_file_release_asset_url!

      Tempfile.create("single-file-cli") do |tmp|
        tmp.binmode
        download_to_io!(download_url, tmp)
        tmp.flush
        tmp.fsync
        FileUtils.chmod(0o755, tmp.path)
        FileUtils.mv(tmp.path, DEFAULT_SINGLE_FILE_CLI, force: true)
      end

      FileUtils.chmod(0o755, DEFAULT_SINGLE_FILE_CLI)
    end
  rescue Errno::EACCES, Errno::EPERM => e
    raise SingleFileNotFoundError,
      "Auto-install failed (permission error writing #{DEFAULT_SINGLE_FILE_CLI.inspect}): #{e.message}. " \
      "Set SINGLE_FILE_CLI_PATH to an installed single-file executable to disable auto-install."
  end

  def valid_single_file_cli_installed?
    return false unless File.exist?(DEFAULT_SINGLE_FILE_CLI)
    return false unless File.executable?(DEFAULT_SINGLE_FILE_CLI)

    _stdout, _stderr, status = Open3.capture3(DEFAULT_SINGLE_FILE_CLI, "--version")
    status.success?
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOEXEC
    false
  end

  def fetch_single_file_release_asset_url!
    asset_name = single_file_asset_name_for_host
    release = github_json!(URI("https://api.github.com/repos/gildas-lormeau/single-file-cli/releases/latest"))

    asset = Array(release["assets"]).find { |a| a["name"] == asset_name }
    unless asset&.dig("browser_download_url").present?
      raise SingleFileNotFoundError,
        "Auto-install failed: could not find release asset #{asset_name.inspect} for this platform. " \
        "Please install single-file manually and set SINGLE_FILE_CLI_PATH."
    end

    asset["browser_download_url"]
  end

  def single_file_asset_name_for_host
    host_os = RbConfig::CONFIG["host_os"].to_s.downcase
    host_cpu = RbConfig::CONFIG["host_cpu"].to_s.downcase

    if host_os.include?("darwin")
      return "single-file-aarch64-apple-darwin" if host_cpu.include?("arm") || host_cpu.include?("aarch64")
      return "single-file-x86_64-apple-darwin" if host_cpu.include?("x86_64") || host_cpu.include?("amd64")
    elsif host_os.include?("linux")
      return "single-file-aarch64-linux" if host_cpu.include?("arm") || host_cpu.include?("aarch64")
      return "single-file-x86_64-linux" if host_cpu.include?("x86_64") || host_cpu.include?("amd64")
    elsif Gem.win_platform?
      return "single-file.exe"
    end

    raise SingleFileNotFoundError,
      "Auto-install is not supported for host_os=#{host_os.inspect}, host_cpu=#{host_cpu.inspect}. " \
      "Please install single-file manually and set SINGLE_FILE_CLI_PATH."
  end

  def github_json!(uri)
    response_body = safe_utf8(http_get_body!(uri, headers: github_headers))
    JSON.parse(response_body)
  rescue JSON::ParserError => e
    raise ArchiveError, "Auto-install failed: could not parse GitHub API response: #{e.message}"
  end

  def github_headers
    headers = default_headers
    token = ENV["GITHUB_TOKEN"].to_s.strip
    headers["Authorization"] = "Bearer #{token}" if token.present?
    headers
  end

  def default_headers
    { "User-Agent" => "Rables" }
  end

  def download_to_io!(url, io, headers: github_headers)
    io.binmode if io.respond_to?(:binmode)
    http_get_stream!(URI(url), headers: headers) { |chunk| io.write(chunk.b) }
  end

  def http_get_body!(uri, headers:, limit: 5)
    body = +"".b
    http_get_stream!(uri, headers: headers, limit: limit) { |chunk| body << chunk.b }
    body
  end

  def http_get_stream!(uri, headers:, limit: 5, &block)
    raise ArchiveError, "Auto-install failed: too many redirects fetching #{uri}" if limit <= 0

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri)
      headers.each { |k, v| request[k] = v }

      http.request(request) do |response|
        case response
        when Net::HTTPSuccess
          response.read_body(&block)
        when Net::HTTPRedirection
          location = response["location"]
          raise ArchiveError, "Auto-install failed: redirect without location fetching #{uri}" if location.blank?
          return http_get_stream!(URI(location), headers: headers, limit: limit - 1, &block)
        else
          raise ArchiveError, "Auto-install failed: HTTP #{response.code} fetching #{uri}"
        end
      end
    end
  rescue SocketError, Timeout::Error, Errno::ECONNRESET, Errno::ECONNREFUSED => e
    raise ArchiveError, "Auto-install failed: network error fetching #{uri}: #{e.message}"
  end

  def single_file_not_found_error(details)
    details = safe_utf8(details)
    SingleFileNotFoundError.new(
      "single-file-cli not found or not executable at #{SINGLE_FILE_CLI.inspect}. " \
      "Auto-install #{auto_install_single_file_cli? ? "was attempted" : "is disabled"} (set SINGLE_FILE_AUTO_INSTALL=0 to disable). " \
      "Error: #{details.presence || "unknown"}"
    )
  end

  def archive_with_single_file(url, tmpdir)
    # Generate safe filename from URL
    filename = generate_filename(url)
    output_path = File.join(tmpdir, filename)

    first_stdout, first_stderr, status = run_single_file_cli(url, output_path, tmpdir)

    unless status.success?
      raise browser_not_found_error(first_stderr, first_stdout) if browser_not_found?(first_stderr, first_stdout)
      raise ArchiveError, "single-file-cli failed: #{safe_utf8(first_stderr)}"
    end

    if File.exist?(output_path)
      Rails.logger.info "[SingleFileArchiveService] Archived #{url} to #{output_path} (#{File.size(output_path)} bytes)"
      return output_path
    end

    if (produced_path = find_single_file_output_file(tmpdir))
      FileUtils.mv(produced_path, output_path, force: true)
      Rails.logger.info "[SingleFileArchiveService] Archived #{url} to #{output_path} (#{File.size(output_path)} bytes)"
      return output_path
    end

    stdout, stderr, status = run_single_file_cli(url, output_path, tmpdir, extra_args: [ "--browser-wait-until=load" ])

    unless status.success?
      raise browser_not_found_error(stderr, stdout) if browser_not_found?(stderr, stdout)
      raise ArchiveError, "single-file-cli failed: #{safe_utf8(stderr)}"
    end

    if File.exist?(output_path)
      Rails.logger.info "[SingleFileArchiveService] Archived #{url} to #{output_path} (#{File.size(output_path)} bytes)"
      return output_path
    end

    if (produced_path = find_single_file_output_file(tmpdir))
      FileUtils.mv(produced_path, output_path, force: true)
      Rails.logger.info "[SingleFileArchiveService] Archived #{url} to #{output_path} (#{File.size(output_path)} bytes)"
      return output_path
    end

    details = safe_utf8(stderr).presence || safe_utf8(stdout)
    details ||= safe_utf8(first_stderr).presence || safe_utf8(first_stdout)
    message = "single-file-cli did not produce output file"
    message = "#{message}: #{truncate_utf8(details)}" if details.present?
    raise ArchiveError, message
  end

  def run_single_file_cli(url, output_path, tmpdir, extra_args: [])
    cmd = [
      SINGLE_FILE_CLI,
      url,
      output_path,
      "--browser-headless",
      *extra_args
    ]

    if (browser_path = browser_executable_path)
      cmd << "--browser-executable-path"
      cmd << browser_path
    end

    capture3_with_timeout(*cmd, chdir: tmpdir, timeout_seconds: SINGLE_FILE_TIMEOUT_SECONDS)
  end

  def capture3_with_timeout(*cmd, chdir:, timeout_seconds:)
    stdout_text = +""
    stderr_text = +""
    status = nil

    Open3.popen3(*cmd, chdir: chdir) do |stdin, stdout, stderr, wait_thr|
      stdin.close

      stdout_thread = Thread.new { stdout.read }
      stderr_thread = Thread.new { stderr.read }

      begin
        Timeout.timeout(timeout_seconds) do
          stdout_text = stdout_thread.value.to_s
          stderr_text = stderr_thread.value.to_s
          status = wait_thr.value
        end
      rescue Timeout::Error
        pid = wait_thr.pid

        begin
          Process.kill("TERM", pid)
        rescue Errno::ESRCH, Errno::EPERM
        end

        begin
          Timeout.timeout(2) { wait_thr.value }
        rescue Timeout::Error
          begin
            Process.kill("KILL", pid)
          rescue Errno::ESRCH, Errno::EPERM
          end
        end

        stdout_thread.join(0.1)
        stderr_thread.join(0.1)

        raise ArchiveError, "single-file-cli timed out after #{timeout_seconds} seconds"
      ensure
        stdout.close rescue nil
        stderr.close rescue nil
      end
    end

    [ stdout_text, stderr_text, status ]
  end

  def browser_executable_path
    return @browser_executable_path if instance_variable_defined?(:@browser_executable_path)

    @browser_executable_path = resolve_browser_executable_path
  end

  def resolve_browser_executable_path
    if (configured_path = ENV["SINGLE_FILE_BROWSER_EXECUTABLE_PATH"].presence)
      configured_path = File.expand_path(configured_path)
      return configured_path if File.executable?(configured_path)

      raise BrowserNotFoundError,
        "SINGLE_FILE_BROWSER_EXECUTABLE_PATH is set but not executable: #{configured_path.inspect}"
    end

    system_path = find_system_browser_executable
    return system_path if system_path

    installed_path = installed_chromium_executable_path
    return installed_path if installed_path

    return nil unless auto_install_chromium?

    install_chromium!
    installed_path = installed_chromium_executable_path
    return installed_path if installed_path

    raise BrowserNotFoundError,
      "Chromium/Chrome executable not found for single-file-cli. " \
      "Install Google Chrome/Chromium or set SINGLE_FILE_BROWSER_EXECUTABLE_PATH to the browser binary path."
  end

  def auto_install_chromium?
    return false if ENV["SINGLE_FILE_BROWSER_AUTO_INSTALL"].to_s.strip == "0"
    true
  end

  def find_system_browser_executable
    host_os = RbConfig::CONFIG["host_os"].to_s.downcase

    if host_os.include?("darwin")
      candidates = [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        File.expand_path("~/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
        File.expand_path("~/Applications/Chromium.app/Contents/MacOS/Chromium")
      ]

      candidates.each do |path|
        return path if File.executable?(path)
      end

      return nil
    end

    find_in_path(
      "google-chrome",
      "google-chrome-stable",
      "chromium",
      "chromium-browser",
      "chrome"
    )
  end

  def find_in_path(*names)
    path_entries = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).reject(&:blank?)
    names.each do |name|
      path_entries.each do |dir|
        candidate = File.join(dir, name)
        return candidate if File.executable?(candidate)
      end
    end
    nil
  end

  def installed_chromium_executable_path
    return nil unless File.directory?(DEFAULT_CHROMIUM_DIR)

    candidate = chromium_executable_candidate_path
    return nil if candidate.blank?

    return nil unless valid_chromium_installation?

    if Gem.win_platform?
      return candidate if File.exist?(candidate)
      return nil
    end

    return candidate if File.executable?(candidate)
    nil
  end

  def valid_chromium_installation?
    candidate = chromium_executable_candidate_path
    return false if candidate.blank?
    return false unless File.exist?(candidate)
    return false if File.directory?(candidate)
    version_file = File.join(DEFAULT_CHROMIUM_DIR, "VERSION")
    return false unless File.exist?(version_file)
    true
  end

  def chromium_executable_candidate_path
    host_os = RbConfig::CONFIG["host_os"].to_s.downcase

    if host_os.include?("darwin")
      return File.join(
        DEFAULT_CHROMIUM_DIR,
        "Google Chrome for Testing.app",
        "Contents",
        "MacOS",
        "Google Chrome for Testing"
      )
    end

    return File.join(DEFAULT_CHROMIUM_DIR, "chrome.exe") if Gem.win_platform?

    File.join(DEFAULT_CHROMIUM_DIR, "chrome")
  end

  def install_chromium!
    FileUtils.mkdir_p(File.dirname(DEFAULT_CHROMIUM_DIR))

    lock_path = "#{DEFAULT_CHROMIUM_DIR}.install.lock"
    File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock_file|
      lock_file.flock(File::LOCK_EX)

      return if valid_chromium_installation?

      FileUtils.rm_rf(DEFAULT_CHROMIUM_DIR) if File.exist?(DEFAULT_CHROMIUM_DIR)

      platform = chrome_for_testing_platform
      version, download_url, sha256 = fetch_chrome_for_testing_download!(platform)

      Rails.logger.info "[SingleFileArchiveService] Installing Chromium (Chrome for Testing #{version}) to #{DEFAULT_CHROMIUM_DIR}"

      Tempfile.create([ "chrome-for-testing", ".zip" ]) do |tmp|
        tmp.binmode
        download_to_io!(download_url, tmp, headers: default_headers)
        tmp.flush
        tmp.fsync

        verify_sha256!(tmp.path, sha256) if sha256.present?

        extracted_dir = Dir.mktmpdir("rables_chromium")
        begin
          extract_zip!(tmp.path, extracted_dir)
          extracted_root = File.join(extracted_dir, chrome_for_testing_root_dir_name(platform))
          raise ArchiveError, "Auto-install failed: extracted Chrome directory not found" unless File.directory?(extracted_root)

          FileUtils.rm_rf(DEFAULT_CHROMIUM_DIR)
          FileUtils.mv(extracted_root, DEFAULT_CHROMIUM_DIR)
          File.write(File.join(DEFAULT_CHROMIUM_DIR, "VERSION"), version)
        ensure
          FileUtils.rm_rf(extracted_dir)
        end
      end

      if (candidate = chromium_executable_candidate_path)
        FileUtils.chmod(0o755, candidate) if File.exist?(candidate) && !Gem.win_platform?
      end

      installed = installed_chromium_executable_path
      return if installed.present?

      raise BrowserNotFoundError,
        "Auto-install completed but Chromium executable was not found under #{DEFAULT_CHROMIUM_DIR.inspect}. " \
        "Set SINGLE_FILE_BROWSER_EXECUTABLE_PATH to an installed browser to bypass auto-install."
    end
  rescue Errno::EACCES, Errno::EPERM => e
    raise BrowserNotFoundError,
      "Auto-install failed (permission error writing #{DEFAULT_CHROMIUM_DIR.inspect}): #{e.message}. " \
      "Set SINGLE_FILE_BROWSER_EXECUTABLE_PATH to an installed browser to disable auto-install."
  end

  def fetch_chrome_for_testing_download!(platform)
    json = JSON.parse(safe_utf8(http_get_body!(CHROME_FOR_TESTING_LKG_URL, headers: default_headers)))
    version = json.dig("channels", "Stable", "version")
    downloads = json.dig("channels", "Stable", "downloads", "chrome")

    raise ArchiveError, "Auto-install failed: could not read Chrome for Testing JSON" if version.blank? || downloads.blank?

    match = Array(downloads).find { |entry| entry["platform"] == platform }
    raise BrowserNotFoundError, "Auto-install is not supported for platform=#{platform.inspect}" unless match

    [ version, match.fetch("url"), match["sha256"].to_s.strip.presence ]
  rescue JSON::ParserError => e
    raise ArchiveError, "Auto-install failed: could not parse Chrome for Testing JSON: #{e.message}"
  end

  def chrome_for_testing_platform
    host_os = RbConfig::CONFIG["host_os"].to_s.downcase
    host_cpu = RbConfig::CONFIG["host_cpu"].to_s.downcase

    if host_os.include?("darwin")
      return "mac-arm64" if host_cpu.include?("arm") || host_cpu.include?("aarch64")
      return "mac-x64" if host_cpu.include?("x86_64") || host_cpu.include?("amd64")
    elsif host_os.include?("linux")
      return "linux64" if host_cpu.include?("x86_64") || host_cpu.include?("amd64")
    elsif Gem.win_platform?
      return "win64"
    end

    raise BrowserNotFoundError,
      "Auto-install is not supported for host_os=#{host_os.inspect}, host_cpu=#{host_cpu.inspect}. " \
      "Please install Chrome/Chromium manually and set SINGLE_FILE_BROWSER_EXECUTABLE_PATH."
  end

  def chrome_for_testing_root_dir_name(platform)
    case platform
    when "mac-arm64"
      "chrome-mac-arm64"
    when "mac-x64"
      "chrome-mac-x64"
    when "linux64"
      "chrome-linux64"
    when "win64"
      "chrome-win64"
    else
      raise BrowserNotFoundError, "Auto-install is not supported for platform=#{platform.inspect}"
    end
  end

  def verify_sha256!(path, expected_sha256)
    expected_sha256 = expected_sha256.to_s.strip.downcase
    return if expected_sha256.blank?

    require "digest"
    actual = Digest::SHA256.file(path).hexdigest.downcase
    return if actual == expected_sha256

    raise ArchiveError, "Auto-install failed: SHA256 mismatch downloading Chromium"
  end

  def extract_zip!(zip_path, dest_dir)
    require "zip"

    dest_root = File.expand_path(dest_dir)
    Zip::File.open(zip_path) do |zip|
      zip.each do |entry|
        entry_name = entry.name.to_s
        next if entry_name.blank?

        target_path = File.expand_path(File.join(dest_root, entry_name))
        unless target_path.start_with?(dest_root + File::SEPARATOR) || target_path == dest_root
          raise ArchiveError, "Auto-install failed: unsafe zip entry path #{entry_name.inspect}"
        end

        if entry.directory?
          FileUtils.mkdir_p(target_path)
          next
        end

        if entry.respond_to?(:symlink?) && entry.symlink?
          raise ArchiveError, "Auto-install failed: zip contains symlink entry #{entry_name.inspect}"
        end
        if entry.respond_to?(:unix_perms) && entry.unix_perms
          file_type = entry.unix_perms & 0o170000
          raise ArchiveError, "Auto-install failed: zip contains symlink entry #{entry_name.inspect}" if file_type == 0o120000
        end

        FileUtils.mkdir_p(File.dirname(target_path))
        entry.extract(entry_name, destination_directory: dest_root) { true }
      end
    end
  end

  def browser_not_found?(stderr, stdout)
    message = safe_utf8(stderr).presence || safe_utf8(stdout)
    return false if message.blank?

    message.match?(/chromium executable not found/i) ||
      message.match?(/browser executable not found/i) ||
      message.match?(/could not find.*(chromium|chrome)/i)
  end

  def browser_not_found_error(stderr, stdout)
    details = safe_utf8(stderr).presence || safe_utf8(stdout)
    message =
      "Chromium/Chrome executable not found for single-file-cli. " \
      "Install Google Chrome/Chromium or set SINGLE_FILE_BROWSER_EXECUTABLE_PATH to the browser binary path."
    message = "#{message} Details: #{truncate_utf8(details)}" if details.present?
    BrowserNotFoundError.new(message)
  end

  def find_single_file_output_file(tmpdir)
    candidates = Dir.glob(File.join(tmpdir, "*")).select do |path|
      File.file?(path) && %w[.html .htm .zip].include?(File.extname(path).downcase)
    end

    return nil if candidates.empty?

    candidates.max_by { |path| File.mtime(path) }
  end

  def truncate_utf8(text, max_bytes: 4000)
    text = safe_utf8(text)
    return text if text.bytesize <= max_bytes

    truncated = text.byteslice(0, max_bytes)
    truncated.force_encoding(Encoding::UTF_8)
    "#{truncated.scrub("�")}\n...(truncated)"
  end

  def generate_filename(url)
    # Create a safe filename from URL
    uri = URI.parse(url)
    safe_name = "#{uri.host}#{uri.path}".gsub(/[^a-zA-Z0-9\-_]/, "_")
    safe_name = safe_name[0..100] # Limit length
    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    "#{safe_name}_#{timestamp}.html"
  end

  def generate_ia_item_name(url)
    # Internet Archive item names must be unique and URL-safe
    # Format: rables-archive-{domain}-{timestamp}
    uri = URI.parse(url)
    safe_domain = uri.host.gsub(/[^a-zA-Z0-9]/, "-")
    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    "rables-archive-#{safe_domain}-#{timestamp}"
  end

  def push_to_git(html_file, archive_item, tmpdir)
    git_integration = @settings.git_integration
    repo_url = git_integration.build_authenticated_url(@settings.repo_url)
    branch = @settings.branch

    repo_dir = File.join(tmpdir, "repo")

    # Clone repository
    run_git("clone", "--branch", branch, "--single-branch", "--depth", "1", repo_url, repo_dir)

    # Copy archived file to repo root
    filename = File.basename(html_file)
    dest_path = File.join(repo_dir, filename)
    FileUtils.cp(html_file, dest_path)

    # Git add, commit, push
    Dir.chdir(repo_dir) do
      run_git("add", filename)

      commit_message = "Archive: #{archive_item.title || archive_item.url}"
      run_git("commit", "-m", commit_message)

      run_git("push", "origin", branch)
    end

    Rails.logger.info "[SingleFileArchiveService] Pushed #{filename} to Git repo"

    filename
  end

  def regenerate_index(tmpdir)
    git_integration = @settings.git_integration
    repo_url = git_integration.build_authenticated_url(@settings.repo_url)
    branch = @settings.branch

    repo_dir = File.join(tmpdir, "repo")

    # Ensure repo is cloned with latest changes
    unless File.directory?(repo_dir)
      run_git("clone", "--branch", branch, "--single-branch", repo_url, repo_dir)
    else
      Dir.chdir(repo_dir) { run_git("pull", "origin", branch) }
    end

    # Generate index.html from all ArchiveItems
    index_content = generate_index_html
    index_path = File.join(repo_dir, "index.html")
    File.write(index_path, index_content)

    Dir.chdir(repo_dir) do
      run_git("add", "index.html")

      # Check if there are changes to commit
      status_output, _, _ = Open3.capture3("git", "status", "--porcelain")
      return if status_output.strip.empty?

      run_git("commit", "-m", "Update archive index")
      run_git("push", "origin", branch)
    end

    Rails.logger.info "[SingleFileArchiveService] Updated index.html"
  end

  def generate_index_html
    items = ArchiveItem.completed.order(archived_at: :desc)

    rows = items.map { |item| generate_table_row(item) }.join("\n")

    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Web Archive</title>
        <style>
          body { font-family: system-ui, -apple-system, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
          h1 { margin-bottom: 10px; }
          .stats { color: #666; margin-bottom: 20px; }
          table { width: 100%; border-collapse: collapse; margin-top: 20px; }
          th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
          th { background-color: #f5f5f5; font-weight: 600; }
          tr:hover { background-color: #f9f9f9; }
          a { color: #0066cc; text-decoration: none; }
          a:hover { text-decoration: underline; }
          .size { color: #666; }
          .date { color: #666; white-space: nowrap; }
        </style>
      </head>
      <body>
        <h1>Web Archive</h1>
        <p class="stats">Total archives: #{items.count}</p>
        <table>
          <thead>
            <tr>
              <th>Title</th>
              <th>Original URL</th>
              <th>Archived</th>
              <th>Size</th>
              <th>Download</th>
            </tr>
          </thead>
          <tbody>
            #{rows}
          </tbody>
        </table>
      </body>
      </html>
    HTML
  end

  def generate_table_row(item)
    title = ERB::Util.html_escape(item.title.presence || item.url)
    url_escaped = ERB::Util.html_escape(item.url)
    url_truncated = ERB::Util.html_escape(item.url.truncate(60))
    file_path_escaped = ERB::Util.html_escape(item.file_path.to_s)
    date = item.archived_at&.strftime("%Y-%m-%d %H:%M") || "-"
    size = item.file_size_formatted || "-"

    <<~HTML
      <tr>
        <td>#{title}</td>
        <td><a href="#{url_escaped}" target="_blank" rel="noopener">#{url_truncated}</a></td>
        <td class="date">#{date}</td>
        <td class="size">#{size}</td>
        <td><a href="#{file_path_escaped}" download>Download</a></td>
      </tr>
    HTML
  end

  def run_git(*args)
    stdout, stderr, status = Open3.capture3("git", *args)

    unless status.success?
      masked_stderr = @settings.git_integration&.mask_token(stderr) || stderr
      masked_stderr = safe_utf8(masked_stderr)
      raise GitOperationError, "Git command failed: git #{args.first} - #{masked_stderr}"
    end

    stdout
  end
end
