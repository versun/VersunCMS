class Admin::ArticlesController < Admin::BaseController
  before_action :set_article, only: [ :show, :edit, :update, :destroy, :publish, :unpublish ]

  def index
    @scope = Article.all
    @articles = fetch_articles(@scope)
    @path = admin_articles_path
  end

  def show
  end

  def new
    @article = Article.new
  end

  def edit
  end

  def create
    @article = Article.new(article_params)

    respond_to do |format|
      if @article.save
        format.html { redirect_to admin_articles_path, notice: "Article was successfully created." }
        format.json { render :show, status: :created, location: @article }
      else
        format.html { render :new }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @article.update(article_params)
        format.html { redirect_to admin_articles_path, notice: "Article was successfully updated." }
        format.json { render :show, status: :ok, location: @article }
      else
        format.html { render :edit }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @article.destroy!

    respond_to do |format|
      format.html { redirect_to admin_articles_path, status: :see_other, notice: "Article was successfully deleted." }
      format.json { head :no_content }
    end
  end

  def drafts
    @scope = Article.draft
    @articles = fetch_articles(@scope)
    @path = drafts_admin_articles_path
    render :index
  end

  def scheduled
    @scope = Article.scheduled
    @articles = fetch_articles(@scope)
    @path = scheduled_admin_articles_path
    render :index
  end

  def publish
    if @article.update(status: :publish)
      redirect_to admin_articles_path, notice: "Article was successfully published."
    else
      redirect_to admin_articles_path, alert: "Failed to publish article."
    end
  end

  def unpublish
    if @article.update(status: :draft)
      redirect_to admin_articles_path, notice: "Article was successfully unpublished."
    else
      redirect_to admin_articles_path, alert: "Failed to unpublish article."
    end
  end

  private

  def set_article
    @article = Article.find_by!(slug: params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :content, :excerpt, :slug, :status, :published_at, :meta_description, :tags, :description, :created_at, :scheduled_at, :send_newsletter, :crosspost_mastodon, :crosspost_twitter, :crosspost_bluesky, social_media_posts_attributes: [ :id, :platform, :url, :_destroy ])
  end
end
