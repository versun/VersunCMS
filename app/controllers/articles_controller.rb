class ArticlesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ] # %i 是一种字面量符号数组的简写方式，表示[:index]
  before_action :set_article, only: %i[ show edit update destroy ]
  before_action :set_time_zone, only: [ :new, :edit ]
  after_action :auto_backup, only: [ :create, :update, :destroy ]

  # GET / or /articles.json
  def index
    respond_to do |format|
      format.html {
        @page = params[:page].present? ? params[:page].to_i : 1
        @per_page = 10

        @articles = if params[:q].present?
          Article.published_posts.full_text_search(
            input: params[:q],
            limit: @per_page
          )
        else
          Article.published_posts.order(created_at: :desc)
        end

        @total_count = @articles.count
        @articles = @articles.paginate(@page, @per_page)
      }

      format.rss {
        @articles = Article.published_posts.order(created_at: :desc)
        render layout: false
      }
    end
  end

  # GET /1 or /1.json
  def show
    unless @article
      redirect_to root_path, notice: "Article Not found."
      return
    end
  end

  # GET /articles/new
  def new
    @article = Article.new

    @article.is_page = params[:is_page] == "true"
    if @article.is_page
      max_order = Article.where(is_page: true).maximum(:page_order) || 0
      @article.page_order = max_order + 1
    end
  end

  # GET /1/edit
  def edit
  end

  # POST / or /articles.json
  def create
    @article = Article.new(article_params)
    path_after_create = @article.is_page ? admin_pages_path : admin_posts_path

    respond_to do |format|
      if @article.save
        refresh_pages if @article.is_page
        format.html { redirect_to path_after_create, notice: "Created successfully." }
        format.json { render :show, status: :created, location: @article }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /1 or /1.json
  def update
    path_after_create = @article.is_page ? admin_pages_path : admin_posts_path

    respond_to do |format|
      if @article.update(article_params)
        refresh_pages if @article.is_page
        format.html { redirect_to path_after_create, notice: "Updated successfully." }
        format.json { render :show, status: :ok, location: @article }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /1 or /1.json
  def destroy
    notice_message = if @article.status != "trash"
      @article.update(status: "trash")
      "Article was successfully moved to trash."
    else
      @article.destroy!
      "Article was successfully destroyed."
    end

    respond_to do |format|
      format.html { redirect_to admin_posts_path, status: :see_other, notice: notice_message }
      format.json { head :no_content }
    end
  end

  private

  def set_article
    @article = Article.find_by(slug: params[:slug])
  end

  def article_params
    params.require(:article).permit(
      :title,
      :content,
      :status,
      :slug,
      :description,
      :is_page,
      :page_order,
      :scheduled_at,
      :crosspost_mastodon,
      :crosspost_twitter,
      :crosspost_urls
    )
  end

  def set_time_zone
    Time.zone = SettingsService.time_zone rescue "UTC"
  end

  def auto_backup
    return unless BackupSetting.first&.auto_backup
    BackupJob.perform_later
  end
end
