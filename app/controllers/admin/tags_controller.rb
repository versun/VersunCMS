class Admin::TagsController < Admin::BaseController
  before_action :set_tag, only: [ :edit, :update, :destroy ]

  def index
    @tags = Tag.alphabetical.all
  end

  def new
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)

    if @tag.save
      redirect_to admin_tags_path, notice: "Tag was successfully created."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @tag.update(tag_params)
      redirect_to admin_tags_path, notice: "Tag was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    if @tag.articles.any?
      redirect_to admin_tags_path, alert: "Cannot delete tag that is in use by articles."
    else
      @tag.destroy
      redirect_to admin_tags_path, status: :see_other, notice: "Tag was successfully deleted."
    end
  end

  private

  def set_tag
    @tag = Tag.find(params[:id])
  end

  def tag_params
    params.require(:tag).permit(:name)
  end
end
