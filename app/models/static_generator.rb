# Static site generator - PORO for generating static HTML files
# Output directory depends on static_generation_destination setting:
# - 'local': uses local_generation_path or public/
# - 'github': uses tmp/static_output/ to avoid polluting public/
class StaticGenerator
  include Rails.application.routes.url_helpers

  PER_PAGE = 20

  GITHUB_OUTPUT_DIR = Rails.root.join("tmp", "static_output")
  PUBLIC_DIR = Rails.root.join("public")

  def output_dir
    @output_dir ||= begin
      settings = Setting.first_or_create
      case settings.static_generation_destination
      when "local"
        if settings.local_generation_path.present?
          normalize_output_dir(settings.local_generation_path)
        else
          PUBLIC_DIR
        end
      when "github"
        # GitHub mode: always generate to tmp directory to avoid polluting public/
        GITHUB_OUTPUT_DIR
      else
        PUBLIC_DIR
      end
    end
  end

  def uploads_dir
    @uploads_dir ||= output_dir.join("uploads")
  end

  def static_source_dir
    @static_source_dir ||= Rails.root.join("storage", "static")
  end

  # Shared list of deployable items (used by GithubDeployService)
  DEPLOY_ITEMS = %w[
    index.html
    search.html
    search.json
    feed.xml
    sitemap.xml
    robots.txt
    assets
    uploads
    static
    page
    pages
    tags
    400.html
    404.html
    422.html
    500.html
    _redirects
    .htaccess
    redirects.js
  ].freeze

  # Get all items to deploy including dynamic article files
  def self.deployable_items
    items = DEPLOY_ITEMS.dup
    article_prefix = Rails.application.config.x.article_route_prefix

    if article_prefix.present?
      items << article_prefix
    else
      # Add individual article HTML files
      Article.published.pluck(:slug).each { |slug| items << "#{slug}.html" }
    end

    items
  end

  def initialize
    @site_settings = CacheableSettings.site_info
    @navbar_items = CacheableSettings.navbar_items
    @article_route_prefix = Rails.application.config.x.article_route_prefix
    @exported_blobs = {} # Cache of exported blob paths
  end

  # Generate all static files
  def generate_all(precompile_assets: true)
    Rails.event.notify("static_generator.generation_started", level: "info", component: "StaticGenerator")

    # Clean old generated files before generating new ones
    clean_generated_files
    ensure_assets_available!(precompile: precompile_assets)

    export_all_images
    generate_index_pages
    generate_search_files
    generate_all_articles
    generate_all_pages
    generate_tags_index
    generate_all_tag_pages
    generate_feed
    generate_sitemap
    generate_redirects
    copy_user_static_files

    Rails.event.notify("static_generator.generation_complete", level: "info", component: "StaticGenerator")
  end

  # Generate static search page + index JSON (for fully static hosting)
  def generate_search_files
    generate_search_index
    generate_search_page
    Rails.event.notify("static_generator.search_files_generated", level: "info", component: "StaticGenerator")
  end

  # Copy user uploaded static files from storage/static and StaticFile records to public/static
  def copy_user_static_files
    static_dest = output_dir.join("static")

    # Clean existing static directory before copying to ensure consistency
    if Dir.exist?(static_dest)
      FileUtils.rm_rf(static_dest)
    end
    FileUtils.mkdir_p(static_dest)

    file_count = 0

    # First, copy files from StaticFile records (Active Storage)
    StaticFile.find_each do |static_file|
      next unless static_file.file.attached?

      begin
        dest_file = static_dest.join(static_file.filename)
        FileUtils.mkdir_p(File.dirname(dest_file))

        # Download blob and save to file
        static_file.file.blob.open do |temp_file|
          FileUtils.cp(temp_file.path, dest_file)
        end

        file_count += 1
        Rails.event.notify("static_generator.static_file_copied", level: "debug", component: "StaticGenerator", filename: static_file.filename)
      rescue => e
        Rails.event.notify("static_generator.static_file_copy_failed", level: "error", component: "StaticGenerator", filename: static_file.filename, error: e.message)
      end
    end

    # Then, copy files from storage/static directory (manual uploads)
    if Dir.exist?(static_source_dir)
      files = Dir.glob("#{static_source_dir}/**/*", File::FNM_DOTMATCH).select do |f|
        # Skip directories and hidden files (except .gitkeep if needed)
        File.file?(f)
      end

      files.each do |source_file|
        begin
          relative_path = Pathname.new(source_file).relative_path_from(Pathname.new(static_source_dir))
          dest_file = static_dest.join(relative_path)
          FileUtils.mkdir_p(File.dirname(dest_file))
          FileUtils.cp(source_file, dest_file)
          file_count += 1
          Rails.event.notify("static_generator.storage_file_copied", level: "debug", component: "StaticGenerator", path: relative_path.to_s)
        rescue => e
          Rails.event.notify("static_generator.file_copy_failed", level: "error", component: "StaticGenerator", file: source_file, error: e.message)
        end
      end
    end

    if file_count > 0
      Rails.event.notify("static_generator.static_files_copied", level: "info", component: "StaticGenerator", count: file_count)
    else
      Rails.event.notify("static_generator.no_static_files", level: "info", component: "StaticGenerator")
    end
  end

  # Export all ActiveStorage images from published content
  def export_all_images
    FileUtils.mkdir_p(uploads_dir)

    # Export images from published articles
    Article.published.includes(:rich_text_content).find_each do |article|
      export_rich_text_images(article.content) if article.content.present?
    end

    # Export images from published pages
    Page.published.includes(:rich_text_content).find_each do |page|
      export_rich_text_images(page.content) if page.content.present?
    end

    Rails.event.notify("static_generator.images_exported", level: "info", component: "StaticGenerator", count: @exported_blobs.size)
  end

  # Generate index pages with pagination (each page has PER_PAGE articles)
  def generate_index_pages
    articles = Article.published.includes(:rich_text_content, :tags).order(created_at: :desc)
    total_pages = (articles.count.to_f / PER_PAGE).ceil
    total_pages = 1 if total_pages == 0

    (1..total_pages).each do |page|
      paginated_articles = articles.offset((page - 1) * PER_PAGE).limit(PER_PAGE)
      html = render_static_partial("articles/static_index", {
        articles: WillPaginate::Collection.create(page, PER_PAGE, articles.count) { |pager|
          pager.replace(paginated_articles.to_a)
        },
        total_count: articles.count
      })

      if page == 1
        write_file("index.html", html)
      end
      write_file("page/#{page}.html", html)
    end

    Rails.event.notify("static_generator.index_pages_generated", level: "info", component: "StaticGenerator", count: total_pages)
  end

  # Generate all article detail pages
  def generate_all_articles
    articles = Article.published.includes(:rich_text_content, :tags, :comments, :social_media_posts)
    articles.find_each do |article|
      generate_article(article)
    end
    Rails.event.notify("static_generator.article_pages_generated", level: "info", component: "StaticGenerator", count: articles.count)
  end

  # Generate single article page
  def generate_article(article)
    return unless article.publish? || article.shared?

    html = render_static_partial("articles/static_show", { article: article })

    # Output path depends on article_route_prefix
    if @article_route_prefix.present?
      write_file("#{@article_route_prefix}/#{article.slug}.html", html)
    else
      write_file("#{article.slug}.html", html)
    end
  end

  # Generate all page detail pages
  def generate_all_pages
    pages = Page.published.includes(:rich_text_content, :comments)
    pages.find_each do |page|
      generate_page(page)
    end
    Rails.event.notify("static_generator.page_files_generated", level: "info", component: "StaticGenerator", count: pages.count)
  end

  # Generate single page
  def generate_page(page)
    return unless page.publish? || page.shared?
    return if page.redirect? # Skip redirect pages

    html = render_static_partial("pages/static_show", { page: page })
    write_file("pages/#{page.slug}.html", html)
  end

  # Generate tags index page
  def generate_tags_index
    tags = Tag.alphabetical.all
    html = render_static_partial("tags/static_index", { tags: tags })
    write_file("tags/index.html", html)
    Rails.event.notify("static_generator.tags_index_generated", level: "info", component: "StaticGenerator")
  end

  # Generate all tag pages with pagination
  def generate_all_tag_pages
    Tag.find_each do |tag|
      generate_tag_pages(tag)
    end
  end

  # Generate pages for a single tag
  def generate_tag_pages(tag)
    articles = tag.articles.published.order(created_at: :desc)
    total_pages = (articles.count.to_f / PER_PAGE).ceil
    total_pages = 1 if total_pages == 0

    (1..total_pages).each do |page|
      paginated_articles = articles.offset((page - 1) * PER_PAGE).limit(PER_PAGE)
      html = render_static_partial("tags/static_show", {
        tag: tag,
        articles: WillPaginate::Collection.create(page, PER_PAGE, articles.count) { |pager|
          pager.replace(paginated_articles.to_a)
        }
      })

      if page == 1
        write_file("tags/#{tag.slug}.html", html)
      end
      write_file("tags/#{tag.slug}/page/#{page}.html", html)
    end
  end

  # Generate RSS feed
  def generate_feed
    articles = Article.published.order(created_at: :desc)
    xml = render_rss_template("articles/index", { articles: articles })
    write_file("feed.xml", xml)
    Rails.event.notify("static_generator.rss_feed_generated", level: "info", component: "StaticGenerator")
  end

  # Generate sitemap
  def generate_sitemap
    articles = Article.published
    pages = Page.published
    xml = render_xml_template("sitemap/index", { articles: articles, pages: pages })
    write_file("sitemap.xml", xml)
    Rails.event.notify("static_generator.sitemap_generated", level: "info", component: "StaticGenerator")
  end

  # Generate redirects for static site
  def generate_redirects
    redirects = Redirect.enabled

    if redirects.empty?
      # Still generate empty redirects.js to avoid 404 errors
      generate_js_redirect_handler(redirects)
      Rails.event.notify("static_generator.empty_redirects_generated", level: "info", component: "StaticGenerator")
      return
    end

    Rails.event.notify("static_generator.redirects_generation_started", level: "info", component: "StaticGenerator", count: redirects.count)

    # Collect all paths that need redirect pages
    redirect_paths = collect_redirect_paths(redirects)

    # Generate HTML redirect pages for each path
    redirect_paths.each do |path_info|
      generate_redirect_page(path_info[:path], path_info[:target_url], path_info[:permanent])
    end

    # Generate _redirects file for Netlify (supports regex)
    generate_netlify_redirects_file(redirects)

    # Generate .htaccess file for Apache (supports regex)
    generate_htaccess_file(redirects)

    # Generate JavaScript redirect handler for client-side redirects (fallback)
    generate_js_redirect_handler(redirects)

    Rails.event.notify("static_generator.redirect_pages_generated", level: "info", component: "StaticGenerator", count: redirect_paths.count)
  end

  # Collect all paths that match redirect rules
  def collect_redirect_paths(redirects)
    paths = []

    # Get all existing paths from the site
    all_paths = collect_all_site_paths

    redirects.each do |redirect|
      # Check existing paths
      all_paths.each do |path|
        if redirect.match?(path)
          target_url = redirect.apply_to(path)
          if target_url
            paths << {
              path: path,
              target_url: target_url,
              permanent: redirect.permanent?,
              redirect: redirect
            }
          end
        end
      end

      # For redirects that match patterns (like /old/* -> /new/*),
      # we can't generate all possible matches, but we can generate
      # a JavaScript-based redirect handler for unmatched paths
    end

    paths.uniq { |p| p[:path] }
  end

  # Collect all paths from the site (articles, pages, tags, etc.)
  def collect_all_site_paths
    paths = [ "/" ]

    # Article paths
    Article.published.find_each do |article|
      if @article_route_prefix.present?
        paths << "/#{@article_route_prefix}/#{article.slug}"
      else
        paths << "/#{article.slug}"
      end
    end

    # Page paths
    Page.published.find_each do |page|
      paths << "/pages/#{page.slug}" unless page.redirect?
    end

    # Tag paths
    Tag.find_each do |tag|
      paths << "/tags/#{tag.slug}"
    end

    # Pagination paths
    article_count = Article.published.count
    total_pages = (article_count.to_f / PER_PAGE).ceil
    (2..total_pages).each { |p| paths << "/page/#{p}" }

    paths
  end

  # Generate a single HTML redirect page
  def generate_redirect_page(path, target_url, permanent)
    # Normalize path: remove leading slash, add .html if needed
    file_path = path.sub(/^\//, "")

    # Handle root path
    if file_path.empty? || file_path == "/"
      file_path = "index.html"
    else
      file_path += ".html" unless file_path.end_with?(".html")
    end

    # Ensure target_url is absolute or starts with /
    target_url = "/#{target_url}" if target_url.present? && !target_url.start_with?("http", "/")

    html = render_static_partial("redirects/static_redirect", {
      target_url: target_url,
      permanent: permanent
    })

    write_file(file_path, html)
  end

  # Generate _redirects file for Netlify
  def generate_netlify_redirects_file(redirects)
    lines = []

    redirects.each do |redirect|
      begin
        regex = Regexp.new(redirect.regex)
        target = redirect.replacement
        status = redirect.permanent? ? 301 : 302

        # Netlify supports regex patterns with /* syntax or full regex
        # Convert our regex to Netlify format
        pattern = redirect.regex

        # Remove leading ^ and trailing $ if present (Netlify doesn't need them)
        pattern = pattern.gsub(/^\^/, "").gsub(/\$$/, "")

        # Netlify uses /* for wildcards, but also supports regex
        # For simple patterns, use Netlify syntax; for complex, use regex
        if pattern.match?(/^[^$*+?()\[\]{}|\\]+$/)
          # Simple literal pattern - use as-is
          lines << "#{pattern} #{target} #{status}"
        else
          # Complex regex - Netlify supports regex with /regex/ syntax
          lines << "/#{pattern}/ #{target} #{status}"
        end
      rescue => e
        Rails.event.notify("static_generator.invalid_redirect_regex", level: "warn", component: "StaticGenerator", regex: redirect.regex, error: e.message, platform: "Netlify")
      end
    end

    if lines.any?
      content = lines.join("\n")
      write_file("_redirects", content)
      Rails.event.notify("static_generator.netlify_redirects_generated", level: "info", component: "StaticGenerator", count: lines.count)
    end
  end

  # Generate .htaccess file for Apache
  def generate_htaccess_file(redirects)
    lines = [
      "# Auto-generated redirect rules",
      "# Enable RewriteEngine",
      "RewriteEngine On",
      ""
    ]

    redirects.each do |redirect|
      begin
        regex = Regexp.new(redirect.regex)
        target = redirect.replacement
        status = redirect.permanent? ? "R=301" : "R=302"

        # Convert regex to Apache RewriteRule pattern
        # Apache uses PCRE regex, so we can use the regex directly with some escaping
        pattern = redirect.regex
        # Escape backslashes and dollar signs for Apache
        pattern = pattern.gsub(/\\/, "\\\\").gsub(/\$/, "\\$")

        lines << "RewriteRule ^#{pattern}$ #{target} [L,#{status}]"
      rescue => e
        Rails.event.notify("static_generator.invalid_redirect_regex", level: "warn", component: "StaticGenerator", regex: redirect.regex, error: e.message, platform: "Apache")
      end
    end

    if lines.length > 4
      content = lines.join("\n")
      write_file(".htaccess", content)
      Rails.event.notify("static_generator.htaccess_generated", level: "info", component: "StaticGenerator", count: lines.length - 4)
    end
  end

  # Generate JavaScript redirect handler as fallback for platforms that don't support server-side redirects
  def generate_js_redirect_handler(redirects)
    if redirects.empty?
      # Generate empty file to avoid 404 errors
      write_file("redirects.js", "// No redirects configured\n")
      return
    end

    js_rules = redirects.map do |redirect|
      {
        regex: redirect.regex,
        replacement: redirect.replacement,
        permanent: redirect.permanent?
      }
    end

    js_content = <<~JAVASCRIPT
      // Auto-generated redirect rules for static sites
      (function() {
        var redirects = #{js_rules.to_json};
        var currentPath = window.location.pathname;
      #{'  '}
        for (var i = 0; i < redirects.length; i++) {
          var rule = redirects[i];
          try {
            var regex = new RegExp(rule.regex);
            if (regex.test(currentPath)) {
              var target = currentPath.replace(regex, rule.replacement);
              if (target !== currentPath) {
                // Use replace for permanent redirects, assign for temporary
                if (rule.permanent) {
                  window.location.replace(target);
                } else {
                  window.location.href = target;
                }
                return;
              }
            }
          } catch (e) {
            console.warn('Invalid redirect regex:', rule.regex, e);
          }
        }
      })();
    JAVASCRIPT

    write_file("redirects.js", js_content)
    Rails.event.notify("static_generator.js_redirects_generated", level: "info", component: "StaticGenerator")
  end

  # Regenerate affected pages when content changes
  def regenerate_for_article(article)
    # Export images from this article first
    export_rich_text_images(article.content) if article.content.present?

    generate_article(article)
    generate_index_pages
    generate_feed
    generate_sitemap

    # Regenerate tag pages for this article's tags
    article.tags.each { |tag| generate_tag_pages(tag) }
  end

  def regenerate_for_page(page)
    # Export images from this page first
    export_rich_text_images(page.content) if page.content.present?

    generate_page(page)
    generate_sitemap
  end

  def regenerate_for_tag(tag)
    generate_tag_pages(tag)
    generate_tags_index
  end

  # Clean all generated static files before regeneration
  def clean_generated_files
    Rails.event.notify("static_generator.cleanup_started", level: "info", component: "StaticGenerator")

    files_to_clean = [
      "index.html",
      "search.html",
      "search.json",
      "feed.xml",
      "sitemap.xml",
      "_redirects",
      ".htaccess",
      "redirects.js"
    ]

    dirs_to_clean = [
      "page",
      "pages",
      "tags",
      "uploads",
      "static"
    ]

    # If output is NOT public/, we need to manage assets inside output_dir too
    dirs_to_clean << "assets" unless output_dir.to_s == PUBLIC_DIR.to_s

    # Add article route prefix directory if configured
    dirs_to_clean << @article_route_prefix if @article_route_prefix.present?

    # Clean root-level files
    files_to_clean.each do |file|
      path = output_dir.join(file)
      if File.exist?(path)
        File.delete(path)
        Rails.event.notify("static_generator.file_deleted", level: "debug", component: "StaticGenerator", file: file)
      end
    end

    # Clean directories
    dirs_to_clean.each do |dir|
      path = output_dir.join(dir)
      if Dir.exist?(path)
        FileUtils.rm_rf(path)
        Rails.event.notify("static_generator.directory_deleted", level: "debug", component: "StaticGenerator", directory: "#{dir}/")
      end
    end

    # Clean article HTML files in root (if no prefix)
    # Note: We clean based on current database records, but also clean any orphaned files
    if @article_route_prefix.blank?
      # Clean files for articles that exist in database (including unpublished ones that might have old files)
      Article.find_each do |article|
        path = output_dir.join("#{article.slug}.html")
        if File.exist?(path)
          File.delete(path)
          Rails.event.notify("static_generator.article_file_deleted", level: "debug", component: "StaticGenerator", file: "#{article.slug}.html")
        end
      end

      # Also clean any orphaned HTML files that don't match any article
      # (in case articles were deleted but files remain)
      existing_slugs = Article.pluck(:slug).to_set
      Dir.glob(output_dir.join("*.html")).each do |html_file|
        filename = File.basename(html_file, ".html")
        # Skip error pages and index
        next if filename.match?(/^(400|404|422|500|index)$/)
        # Skip if it matches an existing article (already cleaned above)
        next if existing_slugs.include?(filename)

        File.delete(html_file)
        Rails.event.notify("static_generator.orphaned_file_deleted", level: "debug", component: "StaticGenerator", file: File.basename(html_file))
      end
    end

    Rails.event.notify("static_generator.cleanup_complete", level: "info", component: "StaticGenerator")
  end

  private

  def normalize_output_dir(path)
    Pathname.new(path.to_s).expand_path(Rails.root).cleanpath
  end

  def generate_search_index
    articles = Article.published.includes(:rich_text_content, :tags).order(created_at: :desc)

    items = articles.map do |article|
      url = if @article_route_prefix.present?
        "/#{@article_route_prefix}/#{article.slug}.html"
      else
        "/#{article.slug}.html"
      end

      {
        title: article.title.to_s,
        url: url,
        description: article.description.to_s,
        tags: article.tags.map(&:name),
        created_at: article.created_at&.iso8601,
        content: article.plain_text_content.to_s.squish[0, 1500]
      }
    end

    write_file("search.json", JSON.pretty_generate(items))
  end

  def generate_search_page
    html = render_static_partial("search/static", {})
    write_file("search.html", html)
  end

  def ensure_assets_available!(precompile: true)
    source_assets_dir = PUBLIC_DIR.join("assets")
    unless assets_present?(source_assets_dir)
      if precompile
        precompile_assets!
      else
        Rails.event.notify(
          "static_generator.assets_missing",
          level: "warn",
          component: "StaticGenerator",
          source: source_assets_dir.to_s
        )
        return
      end
    end

    unless assets_present?(source_assets_dir)
      Rails.event.notify(
        "static_generator.assets_still_missing",
        level: "error",
        component: "StaticGenerator",
        source: source_assets_dir.to_s
      )
      raise "Assets are missing after precompile: #{source_assets_dir}"
    end

    return if output_dir.to_s == PUBLIC_DIR.to_s

    dest_assets_dir = output_dir.join("assets")
    FileUtils.rm_rf(dest_assets_dir) if Dir.exist?(dest_assets_dir)
    FileUtils.mkdir_p(output_dir)
    FileUtils.cp_r(source_assets_dir, dest_assets_dir)
    Rails.event.notify("static_generator.assets_copied", level: "info", component: "StaticGenerator", destination: dest_assets_dir.to_s)
  end

  def assets_present?(assets_dir)
    return false unless Dir.exist?(assets_dir)

    manifest = Dir.glob(assets_dir.join(".sprockets-manifest*.json")).first ||
      Dir.glob(assets_dir.join(".manifest.json")).first
    return true if manifest.present?

    Dir.glob(assets_dir.join("**/*")).any? { |path| File.file?(path) }
  end

  def precompile_assets!
    Rails.event.notify("static_generator.assets_precompile_started", level: "info", component: "StaticGenerator")

    require "rake"
    Rails.application.load_tasks unless Rake::Task.task_defined?("assets:precompile")

    task = Rake::Task["assets:precompile"]
    task.reenable
    task.invoke

    Rails.event.notify("static_generator.assets_precompile_complete", level: "info", component: "StaticGenerator")
  rescue => e
    Rails.event.notify(
      "static_generator.assets_precompile_failed",
      level: "error",
      component: "StaticGenerator",
      error: e.message
    )
    raise
  end

  def render_static_partial(partial, assigns = {})
    # Disable template annotations for cleaner output
    original_annotate = ActionView::Base.annotate_rendered_view_with_filenames
    ActionView::Base.annotate_rendered_view_with_filenames = false

    begin
      controller = StaticRenderController.new
      controller.instance_variable_set(:@_assigns, assigns)
      assigns.each { |k, v| controller.instance_variable_set("@#{k}", v) }

      # Render partial content first
      content = controller.render_to_string(
        partial: partial,
        locals: assigns
      )

      # Then render with layout
      controller.instance_variable_set(:@content_for_layout, content)
      controller.render_to_string(
        template: "layouts/static",
        layout: false,
        locals: { content: content }
      )
    ensure
      ActionView::Base.annotate_rendered_view_with_filenames = original_annotate
    end
  end

  def render_rss_template(template, assigns = {})
    controller = StaticRenderController.new
    assigns.each { |k, v| controller.instance_variable_set("@#{k}", v) }

    controller.render_to_string(
      template: template,
      formats: [ :rss ],
      layout: false
    )
  end

  def render_xml_template(template, assigns = {})
    controller = StaticRenderController.new
    assigns.each { |k, v| controller.instance_variable_set("@#{k}", v) }

    controller.render_to_string(
      template: template,
      formats: [ :xml ],
      layout: false
    )
  end

  def write_file(relative_path, content)
    full_path = output_dir.join(relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))

    # Replace ActiveStorage URLs with static paths in HTML and XML content
    if relative_path.end_with?(".html")
      content = replace_active_storage_urls(content)
    elsif relative_path == "feed.xml"
      content = replace_active_storage_urls_for_rss(content)
    end

    File.write(full_path, content)
    Rails.event.notify("static_generator.file_written", level: "debug", component: "StaticGenerator", path: relative_path)
  end

  # Export images from ActionText rich text content
  def export_rich_text_images(rich_text)
    return unless rich_text&.body&.attachments

    rich_text.body.attachments.each do |attachment|
      next unless attachment.attachable.is_a?(ActiveStorage::Blob)

      blob = attachment.attachable
      export_blob(blob)
    end
  end

  # Export a single ActiveStorage blob to public/uploads
  # Compresses images for faster loading, especially for index pages
  def export_blob(blob, options = {})
    return @exported_blobs[blob.id] if @exported_blobs[blob.id] && !options[:force]

    # Generate unique filename: id-filename.ext
    filename = "#{blob.id}-#{blob.filename}"
    output_path = uploads_dir.join(filename)
    FileUtils.mkdir_p(uploads_dir)

    begin
      if blob.image? && blob.variable?
        # Optimize for index pages: max width 1200px, quality 85%
        # This balances quality and file size for faster page loads
        variant = blob.variant(
          resize_to_limit: [ 1200, 1200 ],
          saver: {
            quality: 85,
            strip: true # Remove metadata to reduce file size
          }
        )

        File.binwrite(output_path, variant.processed.download)
      else
        blob.open do |file|
          FileUtils.cp(file.path, output_path)
        end
      end

      static_path = "/uploads/#{filename}"
      @exported_blobs[blob.id] = static_path

      # Log compression info
      original_size = blob.byte_size
      compressed_size = File.size(output_path)
      compression_ratio = if original_size.to_i.positive?
        ((1 - compressed_size.to_f / original_size) * 100).round(1)
      end

      Rails.event.notify(
        "static_generator.image_exported",
        level: "debug",
        component: "StaticGenerator",
        content_type: blob.content_type,
        path: static_path,
        compression_ratio: compression_ratio
      )

      static_path
    rescue => e
      Rails.event.notify("static_generator.blob_export_failed", level: "error", component: "StaticGenerator", blob_id: blob.id, error: e.message)
      # Fallback to original if variant processing fails
      begin
        blob.open do |file|
          FileUtils.cp(file.path, output_path)
        end
        static_path = "/uploads/#{filename}"
        @exported_blobs[blob.id] = static_path
        Rails.event.notify("static_generator.original_image_exported", level: "warn", component: "StaticGenerator", path: static_path)
        static_path
      rescue => fallback_error
        Rails.event.notify("static_generator.fallback_export_failed", level: "error", component: "StaticGenerator", error: fallback_error.message)
        nil
      end
    end
  end

  # Replace ActiveStorage URLs in HTML with static paths
  def replace_active_storage_urls(html)
    return html if html.blank?

    # Pattern 1: /rails/active_storage/blobs/redirect/:signed_id/*filename
    html = html.gsub(%r{(https?://[^/]+)?/rails/active_storage/(blobs|representations)/(redirect/)?([^/"'\s]+)/[^"'\s]+}) do |match|
      signed_id = $4
      replace_blob_url(signed_id, match)
    end

    # Pattern 2: Full URLs with /uploads/ path that have wrong host
    # Replace http://example.org/uploads/xxx or http://127.0.0.1:3000/uploads/xxx with /uploads/xxx
    html = html.gsub(%r{https?://[^/]+(/uploads/[^"'\s]+)}) do |match|
      $1 # Return just the /uploads/xxx part
    end

    # Pattern 3: action-text-attachment url attribute
    html = html.gsub(/<action-text-attachment([^>]*)url="([^"]+)"/) do |match|
      attrs = $1
      original_url = $2
      new_url = replace_attachment_url(original_url)
      "<action-text-attachment#{attrs}url=\"#{new_url}\""
    end

    # Pattern 4: action-text-attachment url attribute (single quotes)
    html = html.gsub(/<action-text-attachment([^>]*)url='([^']+)'/) do |match|
      attrs = $1
      original_url = $2
      new_url = replace_attachment_url(original_url)
      "<action-text-attachment#{attrs}url='#{new_url}'"
    end

    # Add lazy loading to all images for better performance
    html = add_lazy_loading_to_images(html)

    html
  end

  # Add loading="lazy" attribute to img tags that don't already have it
  def add_lazy_loading_to_images(html)
    return html if html.blank?

    # Match img tags and add loading="lazy" if not present
    html.gsub(/<img\s+([^>]*?)(\s*\/?>)/i) do |match|
      attrs = $1
      closing = $2

      # Skip if already has loading attribute
      if attrs.include?("loading=")
        match
      else
        # Add loading="lazy" and decoding="async" for better performance
        "<img #{attrs} loading=\"lazy\" decoding=\"async\"#{closing}"
      end
    end
  end

  # Replace ActiveStorage URLs in RSS XML with static paths (full URLs)
  def replace_active_storage_urls_for_rss(xml)
    return xml if xml.blank?

    site_url = @site_settings[:url].to_s.chomp("/")

    # Pattern 1: /rails/active_storage/blobs/redirect/:signed_id/*filename
    xml = xml.gsub(%r{(https?://[^/]+)?/rails/active_storage/(blobs|representations)/(redirect/)?([^/"'\s]+)/[^"'\s]+}) do |match|
      signed_id = $4
      static_path = replace_blob_url(signed_id, match)
      # Convert relative path to full URL
      static_path.start_with?("http") ? static_path : "#{site_url}#{static_path}"
    end

    # Pattern 2: action-text-attachment url attribute
    xml = xml.gsub(/<action-text-attachment([^>]*)url="([^"]+)"/) do |match|
      attrs = $1
      original_url = $2
      new_url = replace_attachment_url(original_url)
      # Convert relative path to full URL
      new_url = "#{site_url}#{new_url}" if new_url.start_with?("/")
      "<action-text-attachment#{attrs}url=\"#{new_url}\""
    end

    # Pattern 3: action-text-attachment url attribute (single quotes)
    xml = xml.gsub(/<action-text-attachment([^>]*)url='([^']+)'/) do |match|
      attrs = $1
      original_url = $2
      new_url = replace_attachment_url(original_url)
      # Convert relative path to full URL
      new_url = "#{site_url}#{new_url}" if new_url.start_with?("/")
      "<action-text-attachment#{attrs}url='#{new_url}'"
    end

    # Pattern 4: img src in action-text-attachment
    xml = xml.gsub(%r{<img([^>]*)src="([^"]+)"}) do |match|
      attrs = $1
      original_src = $2
      new_src = replace_attachment_url(original_src)
      # Convert relative path to full URL
      new_src = "#{site_url}#{new_src}" if new_src.start_with?("/")
      "<img#{attrs}src=\"#{new_src}\""
    end

    xml
  end

  # Replace a single attachment URL (from action-text-attachment or img src)
  def replace_attachment_url(original_url)
    return original_url if original_url.blank?

    # If it's already a static path, return as is
    return original_url if original_url.start_with?("/uploads/")

    # If it's an Active Storage URL (full URL or path), try to extract blob and replace
    match = original_url.match(%r{(?:https?://[^/]+)?/rails/active_storage/(blobs|representations)/(redirect/)?([^/"'\s]+)/})
    if match
      signed_id = match[3]
      replace_blob_url(signed_id, original_url)
    else
      original_url
    end
  end

  def replace_blob_url(signed_id, original)
    blob = ActiveStorage::Blob.find_signed(signed_id)
    if blob && @exported_blobs[blob.id]
      @exported_blobs[blob.id]
    elsif blob
      static_path = export_blob(blob)
      static_path || original
    else
      original
    end
  rescue => e
    Rails.event.notify("static_generator.blob_resolve_failed", level: "warn", component: "StaticGenerator", error: e.message)
    original
  end
end

# Internal controller for rendering static pages
class StaticRenderController < ActionController::Base
  include ApplicationHelper
  include ArticlesHelper
  include PagesHelper

  helper_method :site_settings, :navbar_items, :authenticated?, :flash, :rails_api_url

  def site_settings
    CacheableSettings.site_info
  end

  def navbar_items
    CacheableSettings.navbar_items
  end

  def authenticated?
    false
  end

  def flash
    {}
  end
end
