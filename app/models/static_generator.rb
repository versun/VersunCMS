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
        settings.local_generation_path.present? ? Pathname.new(settings.local_generation_path) : PUBLIC_DIR
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
  def generate_all
    Rails.logger.info "[StaticGenerator] Starting full static generation..."

    # Clean old generated files before generating new ones
    clean_generated_files
    ensure_assets_available!

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

    Rails.logger.info "[StaticGenerator] Static generation complete!"
  end

  # Generate static search page + index JSON (for fully static hosting)
  def generate_search_files
    generate_search_index
    generate_search_page
    Rails.logger.info "[StaticGenerator] Generated search files"
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
        Rails.logger.debug "[StaticGenerator] Copied StaticFile: #{static_file.filename}"
      rescue => e
        Rails.logger.error "[StaticGenerator] Failed to copy StaticFile #{static_file.filename}: #{e.message}"
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
          Rails.logger.debug "[StaticGenerator] Copied file from storage/static: #{relative_path}"
        rescue => e
          Rails.logger.error "[StaticGenerator] Failed to copy file #{source_file}: #{e.message}"
        end
      end
    end
    
    if file_count > 0
      Rails.logger.info "[StaticGenerator] Copied #{file_count} user static files to static/"
    else
      Rails.logger.info "[StaticGenerator] No static files to copy"
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

    Rails.logger.info "[StaticGenerator] Exported #{@exported_blobs.size} images"
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

    Rails.logger.info "[StaticGenerator] Generated #{total_pages} index pages"
  end

  # Generate all article detail pages
  def generate_all_articles
    articles = Article.published.includes(:rich_text_content, :tags, :comments, :social_media_posts)
    articles.find_each do |article|
      generate_article(article)
    end
    Rails.logger.info "[StaticGenerator] Generated #{articles.count} article pages"
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
    Rails.logger.info "[StaticGenerator] Generated #{pages.count} page files"
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
    Rails.logger.info "[StaticGenerator] Generated tags index page"
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
    Rails.logger.info "[StaticGenerator] Generated RSS feed"
  end

  # Generate sitemap
  def generate_sitemap
    articles = Article.published
    pages = Page.published
    xml = render_xml_template("sitemap/index", { articles: articles, pages: pages })
    write_file("sitemap.xml", xml)
    Rails.logger.info "[StaticGenerator] Generated sitemap"
  end

  # Generate redirects for static site
  def generate_redirects
    redirects = Redirect.enabled
    
    if redirects.empty?
      # Still generate empty redirects.js to avoid 404 errors
      generate_js_redirect_handler(redirects)
      Rails.logger.info "[StaticGenerator] No redirects configured, generated empty redirects.js"
      return
    end

    Rails.logger.info "[StaticGenerator] Generating redirects for #{redirects.count} redirect rules..."

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

    Rails.logger.info "[StaticGenerator] Generated #{redirect_paths.count} redirect pages and redirect config files"
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
    paths = ["/"]
    
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
        Rails.logger.warn "[StaticGenerator] Skipping invalid redirect regex for Netlify: #{redirect.regex} - #{e.message}"
      end
    end
    
    if lines.any?
      content = lines.join("\n")
      write_file("_redirects", content)
      Rails.logger.info "[StaticGenerator] Generated _redirects file with #{lines.count} rules"
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
        Rails.logger.warn "[StaticGenerator] Skipping invalid redirect regex: #{redirect.regex} - #{e.message}"
      end
    end
    
    if lines.length > 4
      content = lines.join("\n")
      write_file(".htaccess", content)
      Rails.logger.info "[StaticGenerator] Generated .htaccess file with #{lines.length - 4} rules"
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
    Rails.logger.info "[StaticGenerator] Generated redirects.js fallback handler"
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
    Rails.logger.info "[StaticGenerator] Cleaning old generated files..."

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
        Rails.logger.debug "[StaticGenerator] Deleted: #{file}"
      end
    end

    # Clean directories
    dirs_to_clean.each do |dir|
      path = output_dir.join(dir)
      if Dir.exist?(path)
        FileUtils.rm_rf(path)
        Rails.logger.debug "[StaticGenerator] Deleted: #{dir}/"
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
          Rails.logger.debug "[StaticGenerator] Deleted: #{article.slug}.html"
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
        Rails.logger.debug "[StaticGenerator] Deleted orphaned: #{File.basename(html_file)}"
      end
    end

    Rails.logger.info "[StaticGenerator] Cleanup complete"
  end

  private

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

  def ensure_assets_available!
    return if output_dir.to_s == PUBLIC_DIR.to_s

    source_assets_dir = PUBLIC_DIR.join("assets")
    return unless Dir.exist?(source_assets_dir)

    dest_assets_dir = output_dir.join("assets")
    FileUtils.rm_rf(dest_assets_dir) if Dir.exist?(dest_assets_dir)
    FileUtils.mkdir_p(output_dir)
    FileUtils.cp_r(source_assets_dir, dest_assets_dir)
    Rails.logger.info "[StaticGenerator] Copied assets to #{dest_assets_dir}"
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

    # Replace ActiveStorage URLs with static paths in HTML content
    content = replace_active_storage_urls(content) if relative_path.end_with?(".html")

    File.write(full_path, content)
    Rails.logger.debug "[StaticGenerator] Written: #{relative_path}"
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
  def export_blob(blob)
    return @exported_blobs[blob.id] if @exported_blobs[blob.id]

    # Generate unique filename: id-filename.ext
    filename = "#{blob.id}-#{blob.filename}"
    output_path = uploads_dir.join(filename)

    begin
      # Download blob content and save to file
      blob.open do |file|
        FileUtils.cp(file.path, output_path)
      end

      static_path = "/uploads/#{filename}"
      @exported_blobs[blob.id] = static_path
      Rails.logger.debug "[StaticGenerator] Exported image: #{static_path}"
      static_path
    rescue => e
      Rails.logger.error "[StaticGenerator] Failed to export blob #{blob.id}: #{e.message}"
      nil
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

    html
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
    Rails.logger.warn "[StaticGenerator] Could not resolve blob from signed_id: #{e.message}"
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
