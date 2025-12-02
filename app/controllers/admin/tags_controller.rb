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
    # Remove tag from all associated articles before deleting
    @tag.articles.each do |article|
      article.tags.delete(@tag)
    end

    @tag.destroy
    redirect_to admin_tags_path, status: :see_other, notice: "Tag was successfully deleted."
  end

  private

  def find_record_for_batch(id)
    Tag.find_by(id: id)
  end

  def perform_destroy(tag)
    # Remove tag from all associated articles before deleting
    tag.articles.each do |article|
      article.tags.delete(tag)
    end

    tag.destroy
  end

  private

  def set_tag
    @tag = Tag.find(params[:id])
  end

  def tag_params
    params.require(:tag).permit(:name)
  end
end
