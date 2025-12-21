module PagesHelper
  def page_link_path(page)
    page.redirect? ? page.redirect_url : page_path(page.slug)
  end

  def page_link_attributes(page)
    page.redirect? ? { target: "_blank", rel: "noopener" } : {}
  end

  # Safely render HTML content from pages by sanitizing dangerous tags
  # while preserving common formatting elements
  def safe_html_content(html_content)
    return "".html_safe if html_content.blank?

    sanitize(html_content, tags: allowed_html_tags, attributes: allowed_html_attributes)
  end

  private

  # List of allowed HTML tags for page content
  # Includes common formatting, structural, and media tags
  # Excludes script, style, and other potentially dangerous tags
  def allowed_html_tags
    %w[
      p br div span
      h1 h2 h3 h4 h5 h6
      a img
      ul ol li dl dt dd
      table thead tbody tfoot tr th td caption colgroup col
      strong b em i u s strike del ins mark small
      blockquote q cite pre code kbd samp var
      hr
      figure figcaption
      article section aside header footer nav main
      details summary
      abbr address time
      sub sup
      ruby rt rp
      iframe video audio source
    ]
  end

  # List of allowed HTML attributes
  def allowed_html_attributes
    %w[
      href src alt title class id style
      target rel
      width height
      colspan rowspan
      data-controller data-action data-target
      loading
      controls autoplay loop muted
      frameborder allow allowfullscreen
      name content
    ]
  end
end
