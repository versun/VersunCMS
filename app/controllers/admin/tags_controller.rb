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
      ActivityLog.create!(
        action: "created",
        target: "tag",
        level: :info,
        description: "创建标签: #{@tag.name}"
      )
      redirect_to admin_tags_path, notice: "Tag was successfully created."
    else
      ActivityLog.create!(
        action: "failed",
        target: "tag",
        level: :error,
        description: "创建标签失败: #{@tag.errors.full_messages.join(', ')}"
      )
      render :new
    end
  end

  def edit
  end

  def update
    if @tag.update(tag_params)
      ActivityLog.create!(
        action: "updated",
        target: "tag",
        level: :info,
        description: "更新标签: #{@tag.name}"
      )
      redirect_to admin_tags_path, notice: "Tag was successfully updated."
    else
      ActivityLog.create!(
        action: "failed",
        target: "tag",
        level: :error,
        description: "更新标签失败: #{@tag.name} - #{@tag.errors.full_messages.join(', ')}"
      )
      render :edit
    end
  end

  def destroy
    tag_name = @tag.name
    # Remove tag from all associated articles before deleting
    @tag.articles.each do |article|
      article.tags.delete(@tag)
    end

    @tag.destroy
    ActivityLog.create!(
      action: "deleted",
      target: "tag",
      level: :info,
      description: "删除标签: #{tag_name}"
    )
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
