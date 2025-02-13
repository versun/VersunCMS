class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ] # %i 是一种字面量符号数组的简写方式，表示[:index]
  before_action :set_Page, only: %i[ show edit update destroy ]

  def index
  end
  # GET /1
  def show
    if @page.nil? || (!%w[publish shared].include?(@page.status) && !authenticated?)
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
      nil
    end
  end

  # GET /Pages/new
  def new
    @page = Page.new
    max_order = Page.all.maximum(:page_order) || 0
    @page.page_order = max_order + 1
  end

  # GET /1/edit
  def edit
  end

  # POST / or /Pages.json
  def create
    @page = Page.new(page_params)

    respond_to do |format|
      if @page.save
        refresh_pages
        format.html { redirect_to admin_pages_path, notice: "Created successfully." }
        format.json { render :show, status: :created, location: @page }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /1 or /1.json
  def update
    respond_to do |format|
      if @page.update(page_params)
        refresh_pages
        format.html { redirect_to admin_pages_path, notice: "Updated successfully." }
        format.json { render :show, status: :ok, location: @page }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /1 or /1.json
  def destroy
    notice_message = if @page.status != "trash"
                       @page.update(status: "trash")
                       "Page was successfully moved to trash."
    else
                       @page.destroy!
                       "Page was successfully destroyed."
    end

    respond_to do |format|
      format.html { redirect_to admin_pages_path, status: :see_other, notice: notice_message }
      format.json { head :no_content }
    end
  end

  private

  def set_Page
    @page = Page.find_by(slug: params[:slug])
  end

  def page_params
    params.require(:page).permit(
      :title,
      :content,
      :status,
      :slug,
      :page_order
    )
  end
end
