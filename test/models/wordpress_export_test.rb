require "test_helper"

class WordpressExportTest < ActiveSupport::TestCase
  def setup
    @export = WordpressExport.new
  end

  test "should initialize with correct paths" do
    assert @export.export_path.to_s.include?("wordpress_export")
    assert @export.export_path.to_s.include?(".xml")
    assert Dir.exist?(File.dirname(@export.export_path))
    assert Dir.exist?(@export.attachments_dir)
  end

  test "should create valid WXR document" do
    doc = @export.send(:create_wxr_document)

    assert_not_nil doc
    assert_not_nil doc.at_css("rss")
    assert_not_nil doc.at_css("channel")

    # 检查命名空间
    rss = doc.at_css("rss")
    assert_equal "2.0", rss["version"]
    assert rss["xmlns:wp"].include?("wordpress.org")
  end

  test "should add site info" do
    doc = @export.send(:create_wxr_document)
    @export.send(:add_site_info, doc)

    channel = doc.at_css("channel")
    assert_not_nil channel.at_css("title")
    assert_not_nil channel.at_css("link")
    assert_not_nil channel.at_css("wp:wxr_version")
  end

  test "should convert status correctly" do
    assert_equal "publish", @export.send(:wordpress_status, "publish")
    assert_equal "draft", @export.send(:wordpress_status, "draft")
    assert_equal "future", @export.send(:wordpress_status, "schedule")
    assert_equal "trash", @export.send(:wordpress_status, "trash")
    assert_equal "draft", @export.send(:wordpress_status, "unknown")
  end

  test "should handle empty content" do
    result = @export.send(:process_content_for_wordpress, "", nil)
    assert_equal "", result
  end

  test "should create XML file" do
    doc = @export.send(:create_wxr_document)
    @export.send(:save_xml_file, doc)

    assert File.exist?(@export.export_path)

    # 验证XML格式
    xml_content = File.read(@export.export_path)
    doc = Nokogiri::XML(xml_content)
    assert doc.valid?
  end
end
