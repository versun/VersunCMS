require "will_paginate/array"

class StatusesController < ApplicationController
  allow_unauthenticated_access only: %i[ index ]

  # GET / or /statuses.json
  def index
    respond_to do |format|
      format.html {
        # @page = params[:page].present? ? params[:page].to_i : 1
        # @per_page = 50

        # if params[:q].present?
        #   if defined?(ENABLE_ALGOLIASEARCH)
        #     # 使用Algolia搜索
        #     algolia_results = status.algolia_search(params[:q], { hitsPerPage: @per_page, page: @page - 1 }) # Algolia页码从0开始

        #     # 获取Algolia的结果总数
        #     @total_count = algolia_results.size
        #     @statuses = algolia_results
        #   else
        #     # 使用传统搜索
        #     @statuses = status.search_content(params[:q])
        #                        .order(created_at: :desc)
        #                        .paginate(page: @page, per_page: @per_page)
        #     @total_count = @statuses.total_entries
        #   end
        # else
        #   # 不搜索，只分页
        #   @statuses = status.order(created_at: :desc).paginate(page: @page, per_page: @per_page)
        #   @total_count = @statuses.total_entries
        # end
        @statuses = status.order(created_at: :desc).paginate(page: @page, per_page: @per_page)
        @total_count = @statuses.total_entries
      }
    end
  end


  # GET /statuses/new
  def new
    @status = Status.new
  end


  # POST / or /statuses.json
  def create
    @status = Status.new(status_params)
    respond_to do |format|
      if @status.save
        format.html { redirect_to admin_statuses_path, notice: "Created successfully." }
        format.json { render :show, status: :created, location: @status }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @status.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /1 or /1.json
  def update
    respond_to do |format|
      if @status.update(status_params)
        format.html { redirect_to admin_statuses_path, notice: "Updated successfully." }
        format.json { render :show, status: :ok, location: @status }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @status.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /1 or /1.json
  def destroy
    @status.destroy!
    notice_message = "status was successfully destroyed."

    respond_to do |format|
      format.html { redirect_to admin_statuses_path, status: :see_other, notice: notice_message }
      format.json { head :no_content }
    end
  end

  private

  def status_params
    params.expect(status: [ :text,
                            :crosspost_mastodon,
                            :crosspost_twitter,
                            :crosspost_bluesky,
                            social_media_posts_attributes: [ [ :id, :_destroy, :platform, :url ] ] ])
  end
  
end
