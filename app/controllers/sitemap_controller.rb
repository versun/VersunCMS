class SitemapController < ApplicationController
  def index
    respond_to do |format|
      format.xml do
        @articles = Article.published.order(created_at: :desc)
        @pages = Page.published.order(created_at: :desc)
        headers['Content-Type'] = 'application/xml; charset=utf-8'
        render layout: false
      end
    end
  end
end