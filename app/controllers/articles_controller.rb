require "will_paginate/array"
class ArticlesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ] # %i 是一种字面量符号数组的简写方式，表示[:index]
  before_action :set_article, only: %i[ show edit update destroy ]

  # GET / or /articles.json
  def index
    respond_to do |format|
      format.html {
        @page = params[:page].present? ? params[:page].to_i : 1
        @per_page = 10

        if params[:q].present?
          if defined?(ENABLE_ALGOLIASEARCH)
            # 使用Algolia搜索
            algolia_results = Article.algolia_search(params[:q], { hitsPerPage: @per_page, page: @page - 1 }) # Algolia页码从0开始

            # 获取Algolia的结果总数
            @total_count = algolia_results.size
            @articles = algolia_results
          else
            # 使用传统搜索
            @articles = Article.search_content(params[:q])
                               .published
                               .includes(:rich_text_content)
                               .order(created_at: :desc)
                               .paginate(page: @page, per_page: @per_page)
            @total_count = @articles.total_entries
          end
        else
          # 不搜索，只分页
          @articles = Article.published
                             .includes(:rich_text_content)
                             .order(created_at: :desc)
                             .paginate(page: @page, per_page: @per_page)
          @total_count = @articles.total_entries
        end
      }

      format.rss {
        @articles = Article.published.order(created_at: :desc)
        headers["Content-Type"] = "application/xml; charset=utf-8"
        render layout: false
      }
    end
  end

  # GET /1 or /1.json
  def show
    if @article.nil? || (!%w[publish shared].include?(@article.status) && !authenticated?)
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
      nil
    end
  end

  # GET /articles/new
  def new
    @article = Article.new
  end

  # GET /1/edit
  def edit
  end

  # POST / or /articles.json
  def create
    @article = Article.new(article_params)
    respond_to do |format|
      if @article.save
        format.html { redirect_to admin_posts_path, notice: "Created successfully." }
        format.json { render :show, status: :created, location: @article }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /1 or /1.json
  def update
    respond_to do |format|
      if @article.update(article_params)
        format.html { redirect_to admin_posts_path, notice: "Updated successfully." }
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
    params.expect(article: [ :title,
                            :content,
                            :status,
                            :slug,
                            :description,
                            :scheduled_at,
                            :crosspost_mastodon,
                            :crosspost_twitter,
                            :crosspost_bluesky,
                            :send_newsletter,
                            :created_at,
                            social_media_posts_attributes: [ [ :id, :_destroy, :platform, :url ] ] ])
  end
end
