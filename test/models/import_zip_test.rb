require "test_helper"

class ImportZipTest < ActiveSupport::TestCase
  test "imports article source reference and seo fields" do
    slug = "import-seo-source-#{SecureRandom.hex(6)}"
    csv_content = CSV.generate(
      write_headers: true,
      headers: %w[
        id title slug description content status scheduled_at
        source_url source_author source_content
        meta_title meta_description meta_image
        created_at updated_at
      ]
    ) do |csv|
      csv << [
        1,
        "SEO + Source",
        slug,
        "desc",
        "<p>Hello</p>",
        "publish",
        nil,
        "https://example.com/source",
        "Example Author",
        "Example quote",
        "Example Meta Title",
        "Example Meta Description",
        "https://example.com/meta.jpg",
        Time.current,
        Time.current
      ]
    end

    zip_path = build_zip("articles.csv" => csv_content)

    importer = ImportZip.new(zip_path)

    assert importer.import_data, importer.error_message

    article = Article.find_by!(slug: slug)
    assert_equal "https://example.com/source", article.source_url
    assert_equal "Example Author", article.source_author
    assert_equal "Example quote", article.source_content
    assert_equal "Example Meta Title", article.meta_title
    assert_equal "Example Meta Description", article.meta_description
    assert_equal "https://example.com/meta.jpg", article.meta_image
  ensure
    File.delete(zip_path) if zip_path.present? && File.exist?(zip_path)
  end

  test "imports an image-only article without failing validation" do
    csv_content = CSV.generate(write_headers: true, headers: %w[id title slug description content status scheduled_at created_at updated_at]) do |csv|
      csv << [
        1,
        "Image Only",
        "image-only",
        "",
        "<p><img src=\"attachments/a.png\" alt=\"A\"></p>",
        "publish",
        nil,
        Time.current,
        Time.current
      ]
    end

    zip_path = build_zip(
      "articles.csv" => csv_content,
      "attachments/a.png" => "not-a-real-png"
    )

    importer = ImportZip.new(zip_path)

    assert importer.import_data, importer.error_message

    article = Article.find_by(slug: "image-only")
    assert article, "expected article to be imported"
    assert article.html?, "expected importer to fall back to html content type"
    assert_includes article.html_content, "<img"
    assert_includes article.html_content, "/rails/active_storage/blobs/"
    refute_includes article.html_content, "attachments/a.png"
  ensure
    File.delete(zip_path) if zip_path.present? && File.exist?(zip_path)
  end

  test "imports an image-only page without failing validation" do
    csv_content = CSV.generate(write_headers: true, headers: %w[id title slug content status redirect_url page_order created_at updated_at]) do |csv|
      csv << [
        1,
        "Image Only Page",
        "image-only-page",
        "<p><img src=\"attachments/p.png\" alt=\"P\"></p>",
        "publish",
        "",
        0,
        Time.current,
        Time.current
      ]
    end

    zip_path = build_zip(
      "pages.csv" => csv_content,
      "attachments/p.png" => "not-a-real-png"
    )

    importer = ImportZip.new(zip_path)

    assert importer.import_data, importer.error_message

    page = Page.find_by(slug: "image-only-page")
    assert page, "expected page to be imported"
    assert page.html?, "expected importer to fall back to html content type"
    assert_includes page.html_content, "<img"
  ensure
    File.delete(zip_path) if zip_path.present? && File.exist?(zip_path)
  end

  test "imports comments with commentable set" do
    articles_csv = CSV.generate(write_headers: true, headers: %w[id title slug description content status scheduled_at created_at updated_at]) do |csv|
      csv << [
        1,
        "Image Only",
        "image-only",
        "",
        "<p><img src=\"attachments/a.png\" alt=\"A\"></p>",
        "publish",
        nil,
        Time.current,
        Time.current
      ]
    end

    comments_csv = CSV.generate(
      write_headers: true,
      headers: %w[id article_id article_slug parent_id author_name author_url author_username author_avatar_url content platform external_id status published_at url created_at updated_at]
    ) do |csv|
      csv << [
        1,
        "",
        "image-only",
        "",
        "Alice",
        "",
        "",
        "",
        "Nice post",
        "",
        "",
        "approved",
        "",
        "",
        Time.current,
        Time.current
      ]
    end

    zip_path = build_zip(
      "articles.csv" => articles_csv,
      "comments.csv" => comments_csv,
      "attachments/a.png" => "not-a-real-png"
    )

    importer = ImportZip.new(zip_path)

    assert importer.import_data, importer.error_message

    article = Article.find_by!(slug: "image-only")
    comment = Comment.find_by!(author_name: "Alice", content: "Nice post")

    assert_equal "Article", comment.commentable_type
    assert_equal article.id, comment.commentable_id
    assert_equal article.id, comment.article_id
  ensure
    File.delete(zip_path) if zip_path.present? && File.exist?(zip_path)
  end

  test "imports crossposts by platform" do
    Crosspost.delete_all

    crossposts_csv = CSV.generate(
      write_headers: true,
      headers: %w[id platform server_url client_key client_secret access_token access_token_secret api_key api_key_secret username app_password enabled created_at updated_at]
    ) do |csv|
      csv << [
        1,
        "mastodon",
        "https://mastodon.social",
        "test_client_key",
        "test_client_secret",
        "test_access_token",
        "",
        "",
        "",
        "",
        "",
        true,
        Time.current,
        Time.current
      ]
      csv << [
        2,
        "twitter",
        "",
        "",
        "",
        "twitter_access_token",
        "twitter_access_token_secret",
        "twitter_api_key",
        "twitter_api_key_secret",
        "",
        "",
        true,
        Time.current,
        Time.current
      ]
    end

    zip_path = build_zip("crossposts.csv" => crossposts_csv)

    importer = ImportZip.new(zip_path)

    assert importer.import_data, importer.error_message
    assert_equal 2, Crosspost.count

    mastodon = Crosspost.find_by!(platform: "mastodon")
    assert mastodon.enabled?
    assert_equal "test_client_key", mastodon.client_key
    assert_equal "test_client_secret", mastodon.client_secret
    assert_equal "test_access_token", mastodon.access_token

    twitter = Crosspost.find_by!(platform: "twitter")
    assert twitter.enabled?
    assert_equal "twitter_access_token", twitter.access_token
    assert_equal "twitter_access_token_secret", twitter.access_token_secret
    assert_equal "twitter_api_key", twitter.api_key
    assert_equal "twitter_api_key_secret", twitter.api_key_secret
  ensure
    File.delete(zip_path) if zip_path.present? && File.exist?(zip_path)
  end

  test "imports git integrations by provider" do
    git_integrations_csv = CSV.generate(
      write_headers: true,
      headers: %w[id provider name server_url username access_token enabled created_at updated_at]
    ) do |csv|
      csv << [
        1,
        "github",
        "GitHub Updated",
        "https://github.com",
        "",
        "ghp_new_token_67890",
        true,
        Time.current,
        Time.current
      ]
    end

    zip_path = build_zip("git_integrations.csv" => git_integrations_csv)

    importer = ImportZip.new(zip_path)

    assert importer.import_data, importer.error_message

    git_integration = GitIntegration.find_by!(provider: "github")
    assert_equal "GitHub Updated", git_integration.name
    assert_equal "https://github.com", git_integration.server_url
    assert_equal "ghp_new_token_67890", git_integration.access_token
  ensure
    File.delete(zip_path) if zip_path.present? && File.exist?(zip_path)
  end

  test "imports redirects with numeric enabled and permanent flags" do
    redirect_slug = "import-redirect-#{SecureRandom.hex(4)}"
    redirects_csv = CSV.generate(
      write_headers: true,
      headers: %w[id regex replacement enabled permanent created_at updated_at]
    ) do |csv|
      csv << [
        1,
        "^/#{redirect_slug}$",
        "/#{redirect_slug}-target",
        "0",
        "1",
        Time.current,
        Time.current
      ]
    end

    zip_path = build_zip("redirects.csv" => redirects_csv)

    importer = ImportZip.new(zip_path)

    assert importer.import_data, importer.error_message

    redirect = Redirect.find_by!(regex: "^/#{redirect_slug}$")
    refute redirect.enabled?, "expected redirect to remain disabled when enabled is 0"
    assert redirect.permanent?, "expected redirect to be marked permanent when permanent is 1"
  ensure
    File.delete(zip_path) if zip_path.present? && File.exist?(zip_path)
  end

  private

  def build_zip(files)
    require "zip"

    zip_path = Rails.root.join("tmp", "import_zip_test_#{SecureRandom.hex(6)}.zip")

    Zip::File.open(zip_path, create: true) do |zip|
      files.each do |name, content|
        zip.get_output_stream(name) { |f| f.write(content) }
      end
    end

    zip_path
  end
end
