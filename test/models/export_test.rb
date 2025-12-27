require "test_helper"

class ExportTest < ActiveSupport::TestCase
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
