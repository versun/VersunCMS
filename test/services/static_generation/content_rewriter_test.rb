require "test_helper"

class StaticGeneration::ContentRewriterTest < ActiveSupport::TestCase
  test "rewrite_html replaces ActiveStorage blob URLs via resolver" do
    rewriter = StaticGeneration::ContentRewriter.new(
      site_url: "https://example.com",
      resolve_signed_id: ->(signed_id, _original) { "/uploads/#{signed_id}.png" }
    )

    html = %(<img src="/rails/active_storage/blobs/redirect/SIGNED123/test.png">)
    rewritten = rewriter.rewrite_html(html)

    assert_includes rewritten, %(/uploads/SIGNED123.png)
    refute_includes rewritten, "/rails/active_storage/"
  end

  test "rewrite_html normalizes absolute /uploads URLs to relative paths" do
    rewriter = StaticGeneration::ContentRewriter.new(
      site_url: "https://example.com",
      resolve_signed_id: ->(_signed_id, original) { original }
    )

    html = %(<img src="https://example.org/uploads/123-test.png">)
    rewritten = rewriter.rewrite_html(html)

    assert_includes rewritten, %(<img src="/uploads/123-test.png")
    refute_includes rewritten, "https://example.org/uploads"
  end

  test "rewrite_html rewrites action-text-attachment url attribute" do
    rewriter = StaticGeneration::ContentRewriter.new(
      site_url: "https://example.com",
      resolve_signed_id: ->(signed_id, _original) { "/uploads/#{signed_id}.png" }
    )

    html = %(<action-text-attachment url="/rails/active_storage/blobs/redirect/ATTACH1/file.png"></action-text-attachment>)
    rewritten = rewriter.rewrite_html(html)

    assert_includes rewritten, %(url="/uploads/ATTACH1.png")
  end

  test "rewrite_html adds lazy loading to img tags but does not duplicate loading attribute" do
    rewriter = StaticGeneration::ContentRewriter.new(
      site_url: "https://example.com",
      resolve_signed_id: ->(_signed_id, original) { original }
    )

    html = %(<img src="/a.png"><img src="/b.png" loading="eager">)
    rewritten = rewriter.rewrite_html(html)

    assert_includes rewritten, %(<img src="/a.png" loading="lazy" decoding="async">)
    assert_includes rewritten, %(<img src="/b.png" loading="eager">)
    refute_includes rewritten, %(<img src="/b.png" loading="eager" decoding="async">)
  end

  test "rewrite_rss converts static /uploads paths to absolute URLs" do
    rewriter = StaticGeneration::ContentRewriter.new(
      site_url: "https://example.com",
      resolve_signed_id: ->(signed_id, _original) { "/uploads/#{signed_id}.png" }
    )

    xml = %(<enclosure url="/rails/active_storage/blobs/redirect/RSS1/file.png" />)
    rewritten = rewriter.rewrite_rss(xml)

    assert_includes rewritten, "https://example.com/uploads/RSS1.png"
    refute_includes rewritten, "/rails/active_storage/"
  end
end
