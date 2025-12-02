class Admin::ArticlesController < Admin::BaseController
  before_action :set_article, only: [ :show, :edit, :update, :destroy, :publish, :unpublish, :fetch_comments ]

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

  def fetch_comments
    # Get all social media posts for this article
    social_posts = @article.social_media_posts.where.not(url: nil)

    if params[:platform].present?
      social_posts = social_posts.where(platform: params[:platform])
    end

    if social_posts.empty?
      render json: { success: false, message: "No social media posts found for this article" }, status: :unprocessable_entity
      return
    end

    total_fetched = 0
    results = []
    errors = []

    social_posts.each do |post|
      begin
        service = case post.platform
        when "mastodon"
          Integrations::MastodonService.new
        when "bluesky"
          Integrations::BlueskyService.new
        when "twitter"
          Integrations::TwitterService.new
        else
          next
        end

        result = service.fetch_comments(post.url)
        comments_data = result[:comments] || []

        # Create or update comments
        # First pass: create/update all comments and build external_id -> comment mapping
        platform_count = 0
        external_id_to_comment = {}

        comments_data.each do |comment_data|
          # Skip comments without content (required field)
          next if comment_data[:content].blank?

          comment = @article.comments.find_or_initialize_by(
            platform: post.platform,
            external_id: comment_data[:external_id]
          )

          comment.assign_attributes(
            author_name: comment_data[:author_name],
            author_username: comment_data[:author_username],
            author_avatar_url: comment_data[:author_avatar_url],
            content: comment_data[:content],
            published_at: comment_data[:published_at],
            url: comment_data[:url],
            status: :approved  # Auto-approve external comments
          )

          if comment.new_record?
            comment.save!
            platform_count += 1
          elsif comment.changed?
            comment.save!
          end

          # Store mapping for parent lookup
          external_id_to_comment[comment_data[:external_id]] = comment
        end

        # Second pass: set parent relationships based on parent_external_id
        comments_data.each do |comment_data|
          # Skip comments without content to match first pass behavior
          next if comment_data[:content].blank?
          next unless comment_data[:parent_external_id]

          comment = external_id_to_comment[comment_data[:external_id]]
          parent_comment = external_id_to_comment[comment_data[:parent_external_id]]

          # Only set parent if both comment and parent exist and are from the same platform
          if comment && parent_comment && comment.platform == parent_comment.platform
            comment.update(parent_id: parent_comment.id) if comment.parent_id != parent_comment.id
          end
        end

        total_fetched += platform_count
        results << { platform: post.platform.titleize, fetched: platform_count }

        # Log activity
        ActivityLog.create!(
          action: "completed",
          target: "fetch_comments",
          level: :info,
          description: "Fetched #{platform_count} comments from #{post.platform.titleize} for article '#{@article.title}'"
        )
      rescue => e
        error_msg = "Failed to fetch #{post.platform} comments: #{e.message}"
        errors << error_msg
        Rails.logger.error error_msg
        Rails.logger.error e.backtrace.join("\n")

        ActivityLog.create!(
          action: "failed",
          target: "fetch_comments",
          level: :error,
          description: error_msg
        )
      end
    end

    if errors.any?
      render json: {
        success: false,
        message: "Completed with errors. Fetched #{total_fetched} total comments.",
        results: results,
        errors: errors
      }, status: :partial_content
    else
      render json: {
        success: true,
        message: "Successfully fetched #{total_fetched} total comments from #{results.size} platform(s)",
        results: results
      }
    end
  end

  private

  def set_article
    @article = Article.find_by!(slug: params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :content, :excerpt, :slug, :status, :published_at, :meta_description, :tags, :description, :created_at, :scheduled_at, :send_newsletter, :crosspost_mastodon, :crosspost_twitter, :crosspost_bluesky, :tag_list, social_media_posts_attributes: [ :id, :platform, :url, :_destroy ])
  end
end
