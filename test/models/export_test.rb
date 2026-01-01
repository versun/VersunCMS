require "test_helper"

class ExportTest < ActiveSupport::TestCase
  test "exports article source reference and seo fields" do
    slug = "export-seo-source-#{SecureRandom.hex(6)}"
    article = create_published_article(
      slug: slug,
      source_url: "https://example.com/source",
      source_author: "Example Author",
      source_content: "Example quote",
      meta_title: "Example Meta Title",
      meta_description: "Example Meta Description",
      meta_image: "https://example.com/meta.jpg"
    )

    exporter = Export.new

    assert exporter.generate, exporter.error_message
    assert exporter.zip_path.present?
    assert File.exist?(exporter.zip_path), "expected zip to exist at #{exporter.zip_path}"

    Zip::File.open(exporter.zip_path) do |zip|
      entry = zip.find_entry("articles.csv")
      assert entry, "expected articles.csv to exist in zip"

      content = entry.get_input_stream.read
      rows = CSV.parse(content, headers: true)
      exported = rows.find { |row| row["slug"] == slug }
      assert exported, "expected article row to be exported for slug #{slug}"

      assert_equal article.source_url, exported["source_url"]
      assert_equal article.source_author, exported["source_author"]
      assert_equal article.source_content, exported["source_content"]
      assert_equal article.meta_title, exported["meta_title"]
      assert_equal article.meta_description, exported["meta_description"]
      assert_equal article.meta_image, exported["meta_image"]
    end
  ensure
    File.delete(exporter.zip_path) if exporter&.zip_path.present? && File.exist?(exporter.zip_path)
    article&.destroy
  end

  test "includes git_integrations.csv in export zip" do
    exporter = Export.new

    assert exporter.generate, exporter.error_message
    assert exporter.zip_path.present?
    assert File.exist?(exporter.zip_path), "expected zip to exist at #{exporter.zip_path}"

    Zip::File.open(exporter.zip_path) do |zip|
      entry = zip.find_entry("git_integrations.csv")
      assert entry, "expected git_integrations.csv to exist in zip"
      content = entry.get_input_stream.read
      assert_includes content, "provider"
      assert_includes content, "github"
    end
  ensure
    File.delete(exporter.zip_path) if exporter&.zip_path.present? && File.exist?(exporter.zip_path)
  end
end
