require "test_helper"

class ArchiveItemTest < ActiveSupport::TestCase
  test "normalizes url by adding https scheme when missing" do
    item = ArchiveItem.create!(url: "example.com/path")
    assert_equal "https://example.com/path", item.url
  end

  test "keeps existing http scheme" do
    item = ArchiveItem.create!(url: "http://example.com/path")
    assert_equal "http://example.com/path", item.url
  end
end
