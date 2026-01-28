class TagsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]

  def index
    @tags = Tag.alphabetical.includes(:articles).all
  end

  def show
    @tag = Tag.find_by!(slug: params[:slug])
    @articles = @tag.articles.published.includes(:rich_text_content, :tags).order(created_at: :desc).paginate(page: params[:page], per_page: 20)

    respond_to do |format|
      format.html
      format.rss {
        @articles = @tag.articles.published.includes(:rich_text_content, :tags).order(created_at: :desc)
        headers["Content-Type"] = "application/xml; charset=utf-8"
        render layout: false
      }
    end
  end
end
