# Job for generating static files in the background
# Triggered automatically when content changes or manually via rake task
#
# Supports debounced scheduling to avoid redundant regeneration:
# - Multiple triggers within DEBOUNCE_DELAY will only execute once
# - Uses mutex lock to ensure only one generation runs at a time

class GenerateStaticFilesJob < ApplicationJob
  queue_as :default

  DEBOUNCE_DELAY = 1.minute
  CACHE_KEY_PREFIX = "static_gen_scheduled"
  LOCK_KEY = "static_generation_lock"
  LOCK_TIMEOUT = 10.minutes

  # Schedule a debounced static generation
  # Multiple calls within delay period will result in only one execution
  # @param type [String] Type of generation
  # @param id [Integer, nil] ID of the record
  # @param delay [ActiveSupport::Duration] Delay before execution (default: DEBOUNCE_DELAY)
  def self.schedule_debounced(type:, id: nil, delay: DEBOUNCE_DELAY)
    cache_key = debounce_cache_key(type, id)
    scheduled_at = Time.current + delay

    # Update the scheduled timestamp (this is the "debounce" part)
    Rails.cache.write(cache_key, scheduled_at, expires_in: delay + 1.minute)

    # Enqueue the job with delay
    set(wait: delay).perform_later(
      type: type,
      id: id,
      scheduled_at: scheduled_at.to_f,
      debounced: true
    )

    Rails.logger.info "[GenerateStaticFilesJob] Scheduled debounced generation for #{type}:#{id} at #{scheduled_at} (delay: #{delay})"
  end

  def self.debounce_cache_key(type, id)
    "#{CACHE_KEY_PREFIX}:#{type}:#{id || 'all'}"
  end

  # Perform the static generation
  # @param type [String] Type of generation: 'all', 'article', 'page', 'tag'
  # @param id [Integer, nil] ID of the specific record (for article/page/tag types)
  # @param scheduled_at [Float, nil] Timestamp when this job was scheduled (for debounce check)
  # @param debounced [Boolean] Whether this is a debounced job
  def perform(type: "all", id: nil, scheduled_at: nil, debounced: false)
    # Check debounce: skip if a newer job was scheduled
    if debounced && scheduled_at
      cache_key = self.class.debounce_cache_key(type, id)
      latest_scheduled = Rails.cache.read(cache_key)

      if latest_scheduled && latest_scheduled.to_f > scheduled_at.to_f
        Rails.logger.info "[GenerateStaticFilesJob] Skipping outdated job for #{type}:#{id} (newer job scheduled)"
        return
      end
    end

    # Use mutex lock to ensure only one generation runs at a time
    with_lock do
      execute_generation(type, id)
    end
  rescue => e
    Rails.logger.error "[GenerateStaticFilesJob] Error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")

    ActivityLog.create!(
      action: "failed",
      target: "static_generation",
      level: :error,
      description: "静态文件生成失败: #{e.message}"
    )

    raise e
  end

  private

  def execute_generation(type, id)
    start_time = Time.current

    ActivityLog.create!(
      action: "initiated",
      target: "static_generation",
      level: :info,
      description: "开始生成静态文件 (类型: #{type}, ID: #{id || 'all'})"
    )

    generator = StaticGenerator.new

    case type.to_s
    when "all"
      generator.generate_all
    when "article"
      article = Article.find_by(id: id)
      generator.regenerate_for_article(article) if article
    when "page"
      page = Page.find_by(id: id)
      generator.regenerate_for_page(page) if page
    when "tag"
      tag = Tag.find_by(id: id)
      generator.regenerate_for_tag(tag) if tag
    when "index"
      generator.generate_index_pages
    when "feed"
      generator.generate_feed
    when "sitemap"
      generator.generate_sitemap
    else
      Rails.logger.warn "[GenerateStaticFilesJob] Unknown type: #{type}"
      return
    end

    elapsed = (Time.current - start_time).round(2)

    ActivityLog.create!(
      action: "completed",
      target: "static_generation",
      level: :info,
      description: "静态文件生成完成 (类型: #{type}, 耗时: #{elapsed}秒)"
    )

    # Deploy to GitHub if configured
    deploy_to_github_if_configured
  end

  def deploy_to_github_if_configured
    settings = Setting.first_or_create
    return unless settings.static_generation_destination == "github"

    Integrations::GithubDeployService.new.deploy
  end

  def with_lock(&block)
    # Simple file-based lock for single-server deployment
    lock_file = Rails.root.join("tmp", "static_generation.lock")
    FileUtils.mkdir_p(File.dirname(lock_file))

    File.open(lock_file, File::RDWR | File::CREAT) do |f|
      # Try to acquire exclusive lock, wait if another process holds it
      if f.flock(File::LOCK_EX | File::LOCK_NB)
        begin
          yield
        ensure
          f.flock(File::LOCK_UN)
        end
      else
        Rails.logger.info "[GenerateStaticFilesJob] Another generation is running, waiting..."
        f.flock(File::LOCK_EX) # Wait for lock
        begin
          yield
        ensure
          f.flock(File::LOCK_UN)
        end
      end
    end
  end
end
