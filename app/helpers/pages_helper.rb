module PagesHelper
  def page_link_path(page)
    page.redirect? ? page.redirect_url : page_path(page.slug)
  end

  def page_link_attributes(page)
    page.redirect? ? { target: "_blank", rel: "noopener" } : {}
  end
end
