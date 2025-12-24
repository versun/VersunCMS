require "test_helper"

class Services::ContentBuilderTest < ActiveSupport::TestCase
  def setup
    @builder = Class.new do
      include Services::ContentBuilder
    end.new
  end

  test "build_content returns full title and content when within max_length" do
    result = @builder.build_content("hello-world", "Hello", "World", nil, max_length: 100)
    assert_equal "Hello\nWorld", result
    refute_includes result, "Read more:"
  end

  test "build_content includes a link and truncates when content exceeds max_length" do
    long_text = "A" * 200
    result = @builder.build_content("slug-123", "A title", long_text, nil, max_length: 80)

    assert_includes result, "Read more:"
    assert_includes result, "slug-123"
    assert_includes result, "..."
  end

  test "build_content adds link when always_add_link is true" do
    result = @builder.build_content("slug-456", "Hi", "There", nil, max_length: 300, always_add_link: true)

    assert_includes result, "Read more:"
    assert_includes result, "slug-456"
  end

  test "count_chars counts non-ascii as double when enabled" do
    assert_equal 2, @builder.count_chars("a中", false)
    assert_equal 3, @builder.count_chars("a中", true)
  end
end
