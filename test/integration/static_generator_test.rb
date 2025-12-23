require "test_helper"
require "stringio"

class StaticGeneratorIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @settings = Setting.first_or_create
    @original_deploy_provider = @settings.deploy_provider
    @original_path = @settings.local_generation_path
    @original_prefix = Rails.application.config.x.article_route_prefix

    # Use a temporary directory for all test output
    @test_output_dir = Rails.root.join("tmp", "static_generator_integration_test_#{Process.pid}")
    FileUtils.rm_rf(@test_output_dir)
    FileUtils.mkdir_p(@test_output_dir)

    @settings.update!(
      deploy_provider: "local",
      local_generation_path: @test_output_dir.to_s
    )
  end

  def teardown
    @settings.update!(
      deploy_provider: @original_deploy_provider,
      local_generation_path: @original_path
    )
    Rails.application.config.x.article_route_prefix = @original_prefix

    FileUtils.rm_rf(@test_output_dir)
  end

  # ============================================
  # CSS and JS Assets Output Tests
  # ============================================

  test "generate_all copies assets directory to output" do
    # Skip precompile in test to avoid slow asset compilation
    # Instead, mock assets presence by creating them manually
    setup_mock_assets

    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    assets_dir = @test_output_dir.join("assets")
    assert Dir.exist?(assets_dir), "Assets directory should exist in output"
  end

  test "assets directory contains CSS files" do
    setup_mock_assets

    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    assets_dir = @test_output_dir.join("assets")
    css_files = Dir.glob(assets_dir.join("**/*.css"))
    assert css_files.any?, "Should have at least one CSS file in assets"
  end

  test "assets directory contains JS files" do
    setup_mock_assets

    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    assets_dir = @test_output_dir.join("assets")
    js_files = Dir.glob(assets_dir.join("**/*.js"))
    assert js_files.any?, "Should have at least one JS file in assets"
  end

  test "assets manifest file is present" do
    setup_mock_assets

    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    assets_dir = @test_output_dir.join("assets")
    manifest_files = Dir.glob(assets_dir.join(".sprockets-manifest*.json")) +
                     Dir.glob(assets_dir.join(".manifest.json"))
    assert manifest_files.any?, "Should have manifest file in assets"
  end

  # ============================================
  # Rich Text Images Export Tests
  # ============================================

  test "exports images from rich text content to uploads directory" do
    # Create an image blob
    blob = create_test_image_blob

    # Create article with rich text containing the image
    article = Article.new(
      title: "Article with Image",
      slug: "article-with-image-#{Time.current.to_i}",
      description: "Test article",
      status: :publish
    )
    article.content = create_rich_text_with_image(blob)
    article.save!

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    uploads_dir = @test_output_dir.join("uploads")
    assert Dir.exist?(uploads_dir), "Uploads directory should exist"

    # Check the image file exists
    image_files = Dir.glob(uploads_dir.join("*"))
    assert image_files.any?, "Should have exported image files"

    # Check specific file naming convention: id-filename
    expected_pattern = "#{blob.id}-"
    matching_files = image_files.select { |f| File.basename(f).start_with?(expected_pattern) }
    assert matching_files.any?, "Should have image with correct naming pattern (id-filename)"
  end

  test "exports PNG images correctly" do
    blob = create_test_png_blob

    article = create_published_article_with_image(blob, "png-image-article")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    uploads_dir = @test_output_dir.join("uploads")
    png_files = Dir.glob(uploads_dir.join("*.png"))
    assert png_files.any?, "Should have exported PNG image"
  end

  test "exports SVG images without variant processing" do
    svg_content = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <rect width="100" height="100" fill="blue"/>
      </svg>
    SVG

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(svg_content),
      filename: "test-icon.svg",
      content_type: "image/svg+xml"
    )

    article = create_published_article_with_image(blob, "svg-image-article")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    uploads_dir = @test_output_dir.join("uploads")
    svg_files = Dir.glob(uploads_dir.join("*.svg"))
    assert svg_files.any?, "Should have exported SVG image"

    # Verify SVG content is preserved
    exported_svg = File.read(svg_files.first)
    assert_includes exported_svg, "xmlns", "SVG should have xmlns attribute"
    assert_includes exported_svg, "rect", "SVG should contain rect element"
  end

  test "replaces ActiveStorage URLs with static paths in HTML" do
    blob = create_test_image_blob

    slug = "url-replacement-test-#{Time.current.to_i}"
    article = Article.new(
      title: "URL Replacement Test",
      slug: slug,
      description: "Test article",
      status: :publish
    )
    article.content = create_rich_text_with_image(blob)
    article.save!

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    # Read the generated HTML file
    html_file = @test_output_dir.join("#{slug}.html")
    assert File.exist?(html_file), "Article HTML file should exist at #{html_file}"

    html_content = File.read(html_file)

    # Should NOT contain ActiveStorage URLs
    refute_match %r{/rails/active_storage/}, html_content,
      "HTML should not contain ActiveStorage URLs"

    # Should contain /uploads/ paths
    assert_match %r{/uploads/}, html_content,
      "HTML should contain /uploads/ static paths"
  end

  test "adds lazy loading attributes to images" do
    blob = create_test_image_blob

    slug = "lazy-loading-test-#{Time.current.to_i}"
    article = Article.new(
      title: "Lazy Loading Test",
      slug: slug,
      description: "Test article",
      status: :publish
    )
    article.content = create_rich_text_with_image(blob)
    article.save!

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    html_file = @test_output_dir.join("#{slug}.html")
    assert File.exist?(html_file), "Article HTML file should exist at #{html_file}"

    html_content = File.read(html_file)

    assert_match /loading="lazy"/, html_content,
      "Images should have lazy loading attribute"
    assert_match /decoding="async"/, html_content,
      "Images should have async decoding attribute"
  end

  test "exports images from published pages" do
    blob = create_test_image_blob

    page = Page.new(
      title: "Page with Image",
      slug: "page-with-image-#{Time.current.to_i}",
      status: :publish
    )
    page.content = create_rich_text_with_image(blob)
    page.save!

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    uploads_dir = @test_output_dir.join("uploads")
    image_files = Dir.glob(uploads_dir.join("*"))
    assert image_files.any?, "Should have exported image from page"

    # Verify page HTML file exists
    page_html = @test_output_dir.join("pages", "#{page.slug}.html")
    assert File.exist?(page_html), "Page HTML file should exist"
  end

  # ============================================
  # Dynamic Route Redirect Tests
  # ============================================

  test "generates article files in root when no prefix is configured" do
    Rails.application.config.x.article_route_prefix = nil

    article = create_published_article(
      title: "Root Article",
      slug: "root-article-test"
    )

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    # Article should be at root level
    article_file = @test_output_dir.join("root-article-test.html")
    assert File.exist?(article_file), "Article file should exist at root level"

    # Should NOT be in a subdirectory
    prefix_dir = @test_output_dir.join("blog", "root-article-test.html")
    refute File.exist?(prefix_dir), "Article should not be in blog/ subdirectory"
  end

  test "generates article files in prefix directory when configured" do
    Rails.application.config.x.article_route_prefix = "blog"

    article = create_published_article(
      title: "Prefixed Article",
      slug: "prefixed-article-test"
    )

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    # Article should be in blog/ directory
    article_file = @test_output_dir.join("blog", "prefixed-article-test.html")
    assert File.exist?(article_file), "Article file should exist in blog/ directory"

    # Should NOT be at root level
    root_file = @test_output_dir.join("prefixed-article-test.html")
    refute File.exist?(root_file), "Article should not be at root level"
  end

  test "generates pagination files correctly" do
    # Create enough articles to trigger pagination
    25.times do |i|
      create_published_article(
        title: "Pagination Test Article #{i}",
        slug: "pagination-article-#{i}-#{Time.current.to_i}"
      )
    end

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    # Check index.html
    assert File.exist?(@test_output_dir.join("index.html")), "index.html should exist"

    # Check page directory and pagination files
    page_dir = @test_output_dir.join("page")
    assert Dir.exist?(page_dir), "page/ directory should exist"

    assert File.exist?(page_dir.join("1.html")), "page/1.html should exist"
    assert File.exist?(page_dir.join("2.html")), "page/2.html should exist"
  end

  test "generates tag pages with correct structure" do
    tag = create_tag(name: "TestTag", slug: "test-tag")
    article = create_published_article(title: "Tagged Article", slug: "tagged-article-test")
    article.tags << tag

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    # Check tags index
    assert File.exist?(@test_output_dir.join("tags", "index.html")), "tags/index.html should exist"

    # Check tag page
    assert File.exist?(@test_output_dir.join("tags", "test-tag.html")), "tags/test-tag.html should exist"

    # Check tag pagination directory
    tag_page_dir = @test_output_dir.join("tags", "test-tag", "page")
    assert Dir.exist?(tag_page_dir), "tags/test-tag/page/ directory should exist"
    assert File.exist?(tag_page_dir.join("1.html")), "tags/test-tag/page/1.html should exist"
  end

  test "generates redirect files for configured redirects" do
    Redirect.create!(
      regex: "^/old-path$",
      replacement: "/new-path",
      enabled: true,
      permanent: true
    )

    # Create an article at /old-path to trigger redirect page generation
    create_published_article(title: "Old Path Article", slug: "old-path")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    # Check redirect files
    assert File.exist?(@test_output_dir.join("redirects.js")), "redirects.js should exist"
    assert File.exist?(@test_output_dir.join("_redirects")), "_redirects file should exist"
    assert File.exist?(@test_output_dir.join(".htaccess")), ".htaccess file should exist"
  end

  test "generates search files" do
    create_published_article(title: "Searchable Article", slug: "searchable-article")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    # Check search files
    assert File.exist?(@test_output_dir.join("search.html")), "search.html should exist"
    assert File.exist?(@test_output_dir.join("search.json")), "search.json should exist"

    # Verify search.json contains article data
    search_json = JSON.parse(File.read(@test_output_dir.join("search.json")))
    assert search_json.any?, "search.json should have entries"

    article_entry = search_json.find { |a| a["title"] == "Searchable Article" }
    assert article_entry, "search.json should contain the article"
    assert article_entry["url"], "Article entry should have URL"
  end

  test "generates RSS feed" do
    @settings.update!(url: "https://example.com")
    CacheableSettings.refresh_site_info

    create_published_article(title: "RSS Article", slug: "rss-article")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    feed_file = @test_output_dir.join("feed.xml")
    assert File.exist?(feed_file), "feed.xml should exist"

    feed_content = File.read(feed_file)
    assert_includes feed_content, "RSS Article", "Feed should contain article title"
    assert_includes feed_content, "<rss", "Feed should be valid RSS"
    assert_match %r{<link>https://example\.com/(?:[^<]*/)?rss-article\.html</link>}, feed_content,
      "Feed item link should include .html for static hosting"
  end

  test "RSS feed includes prefix and .html when configured" do
    @settings.update!(url: "https://example.com")
    CacheableSettings.refresh_site_info
    Rails.application.config.x.article_route_prefix = "posts"

    create_published_article(title: "Prefixed RSS Article", slug: "prefixed-rss-article")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    feed_content = File.read(@test_output_dir.join("feed.xml"))
    assert_match %r{<link>https://example\.com/posts/prefixed-rss-article\.html</link>}, feed_content,
      "Feed item link should include prefix and .html"
  end

  test "generates sitemap" do
    @settings.update!(url: "https://example.com")
    CacheableSettings.refresh_site_info

    article = create_published_article(title: "Sitemap Article", slug: "sitemap-article")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    sitemap_file = @test_output_dir.join("sitemap.xml")
    assert File.exist?(sitemap_file), "sitemap.xml should exist"

    sitemap_content = File.read(sitemap_file)
    assert_includes sitemap_content, "sitemap-article", "Sitemap should contain article slug"
    assert_includes sitemap_content, "<urlset", "Sitemap should be valid XML"
    assert_match %r{<loc>https://example\.com/(?:[^<]*/)?sitemap-article\.html</loc>}, sitemap_content,
      "Sitemap loc should include .html for static hosting"
  end

  test "sitemap includes prefix and .html when configured" do
    @settings.update!(url: "https://example.com")
    CacheableSettings.refresh_site_info
    Rails.application.config.x.article_route_prefix = "posts"

    create_published_article(title: "Prefixed Sitemap Article", slug: "prefixed-sitemap-article")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    sitemap_content = File.read(@test_output_dir.join("sitemap.xml"))
    assert_match %r{<loc>https://example\.com/posts/prefixed-sitemap-article\.html</loc>}, sitemap_content,
      "Sitemap loc should include prefix and .html"
  end

  test "generated article page share URL includes .html" do
    @settings.update!(url: "https://example.com")
    CacheableSettings.refresh_site_info

    article = create_published_article(title: "Share Link Article", slug: "share-link-article")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    article_file = @test_output_dir.join("#{article.slug}.html")
    assert File.exist?(article_file), "Article HTML file should exist"

    content = File.read(article_file)
    assert_match %r{<meta property="og:url" content="https://example\.com/share-link-article\.html">}, content,
      "OG URL should include .html"
    assert_match %r{copyToClipboard\('https://example\.com/share-link-article\.html'\)}, content,
      "Share copy link should include .html"
  end

  test "generated article page share URL includes prefix and .html" do
    @settings.update!(url: "https://example.com")
    CacheableSettings.refresh_site_info
    Rails.application.config.x.article_route_prefix = "posts"

    article = create_published_article(title: "Prefixed Share Link", slug: "prefixed-share-link")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    article_file = @test_output_dir.join("posts", "#{article.slug}.html")
    assert File.exist?(article_file), "Prefixed article HTML file should exist"

    content = File.read(article_file)
    assert_match %r{<meta property="og:url" content="https://example\.com/posts/prefixed-share-link\.html">}, content,
      "OG URL should include prefix and .html"
    assert_match %r{copyToClipboard\('https://example\.com/posts/prefixed-share-link\.html'\)}, content,
      "Share copy link should include prefix and .html"
  end

  test "search.json contains correct URLs based on article prefix" do
    Rails.application.config.x.article_route_prefix = "posts"

    create_published_article(title: "Prefix URL Test", slug: "prefix-url-test")

    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    search_json = JSON.parse(File.read(@test_output_dir.join("search.json")))
    article_entry = search_json.find { |a| a["title"] == "Prefix URL Test" }

    assert_match %r{^/posts/prefix-url-test\.html$}, article_entry["url"],
      "URL should include article route prefix"
  end

  test "copy_user_static_files copies both StaticFile records and storage/static directory" do
    # Create a StaticFile record (ActiveStorage-backed)
    static_file = StaticFile.new(filename: "nested/from-db.txt")
    static_file.file.attach(
      io: StringIO.new("from-db"),
      filename: "from-db.txt",
      content_type: "text/plain"
    )
    static_file.save!

    # Create a manual file in storage/static
    source_dir = Rails.root.join("storage", "static")
    FileUtils.mkdir_p(source_dir)
    source_file = source_dir.join("from-storage-#{Process.pid}.txt")
    File.write(source_file, "from-storage")

    # Seed an existing output file that should be removed on copy
    existing_output = @test_output_dir.join("static", "old.txt")
    FileUtils.mkdir_p(existing_output.dirname)
    File.write(existing_output, "old")

    generator = StaticGenerator.new
    generator.copy_user_static_files

    assert File.exist?(@test_output_dir.join("static", "nested", "from-db.txt"))
    assert_equal "from-db", File.read(@test_output_dir.join("static", "nested", "from-db.txt"))

    assert File.exist?(@test_output_dir.join("static", source_file.basename))
    assert_equal "from-storage", File.read(@test_output_dir.join("static", source_file.basename))

    refute File.exist?(existing_output), "Old output static files should be cleaned before copying"
  ensure
    File.delete(source_file) if defined?(source_file) && source_file && File.exist?(source_file)
  end

  test "cleans old files before regeneration" do
    # First generation
    setup_mock_assets
    generator = StaticGenerator.new
    generator.generate_all(precompile_assets: false)

    # Create an orphan file that should be cleaned
    orphan_file = @test_output_dir.join("orphan-article.html")
    File.write(orphan_file, "<html>orphan</html>")
    assert File.exist?(orphan_file), "Orphan file should exist before cleanup"

    # Regenerate
    generator2 = StaticGenerator.new
    generator2.generate_all(precompile_assets: false)

    refute File.exist?(orphan_file), "Orphan file should be cleaned after regeneration"
  end

  private

  def setup_mock_assets
    # Create mock assets in public/assets for testing
    source_assets_dir = Rails.root.join("public", "assets")
    FileUtils.mkdir_p(source_assets_dir)

    # Create mock CSS file
    File.write(source_assets_dir.join("application-test123.css"), "body { color: black; }")
    File.write(source_assets_dir.join("static-test123.css"), ".static { display: block; }")

    # Create mock JS file
    File.write(source_assets_dir.join("application-test123.js"), "console.log('test');")

    # Create mock manifest
    manifest = {
      "files" => {
        "application-test123.css" => { "digest" => "test123" },
        "static-test123.css" => { "digest" => "test123" },
        "application-test123.js" => { "digest" => "test123" }
      },
      "assets" => {
        "application.css" => "application-test123.css",
        "static.css" => "static-test123.css",
        "application.js" => "application-test123.js"
      }
    }
    File.write(source_assets_dir.join(".sprockets-manifest-test.json"), manifest.to_json)
  end

  def create_test_image_blob
    # Create a minimal valid JPEG
    jpeg_data = create_minimal_jpeg
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(jpeg_data),
      filename: "test-image.jpg",
      content_type: "image/jpeg"
    )
  end

  def create_test_png_blob
    # Create a minimal valid PNG
    png_data = create_minimal_png
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(png_data),
      filename: "test-image.png",
      content_type: "image/png"
    )
  end

  def create_minimal_jpeg
    # Minimal valid JPEG (1x1 pixel, red)
    [
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
      0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
      0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
      0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
      0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
      0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
      0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
      0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03,
      0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D,
      0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
      0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
      0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72,
      0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
      0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45,
      0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
      0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
      0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
      0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3,
      0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6,
      0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
      0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
      0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4,
      0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01,
      0x00, 0x00, 0x3F, 0x00, 0xFB, 0xD5, 0xDB, 0x20, 0xB8, 0x03, 0x8C, 0x51,
      0x60, 0x9E, 0xE3, 0xAD, 0x0D, 0x00, 0x86, 0x00, 0x00, 0x00, 0xFF, 0xD9
    ].pack("C*")
  end

  def create_minimal_png
    # Minimal valid PNG (1x1 pixel, red)
    [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
      0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x05, 0xFE, 0xD4, 0xEF, 0x00, 0x00,
      0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ].pack("C*")
  end

  def create_rich_text_with_image(blob)
    # Create ActionText content with an embedded image
    signed_id = blob.signed_id
    url = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)

    ActionText::Content.new(<<~HTML)
      <div>
        <p>Article content with image:</p>
        <action-text-attachment sgid="#{blob.attachable_sgid}" content-type="#{blob.content_type}" url="#{url}" filename="#{blob.filename}">
          <img src="#{url}" />
        </action-text-attachment>
      </div>
    HTML
  end

  def create_published_article_with_image(blob, slug_prefix)
    article = Article.new(
      title: "Article with #{blob.filename}",
      slug: "#{slug_prefix}-#{Time.current.to_i}",
      description: "Test article with image",
      status: :publish
    )
    article.content = create_rich_text_with_image(blob)
    article.save!
    article
  end
end
