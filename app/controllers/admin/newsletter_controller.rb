class Admin::NewsletterController < Admin::BaseController
  def show
    @listmonk = Listmonk.first_or_initialize
    @activity_logs = ActivityLog.track_activity("newsletter")
    
    # Fetch lists and templates if configuration exists and is saved in database
    if @listmonk.persisted? && @listmonk.configured?
      @lists = @listmonk.fetch_lists
      @templates = @listmonk.fetch_templates
    else
      @lists = []
      @templates = []
    end
  end

  def verify
    # Create a temporary Listmonk instance with form data (not persisted)
    @listmonk = Listmonk.new(verify_params)
    
    if @listmonk.configured?
      lists = @listmonk.fetch_lists
      templates = @listmonk.fetch_templates
      
      # Check if fetch was successful by verifying we got data back
      if lists.present? && templates.present?
        render json: {
          success: true,
          lists: lists,
          templates: templates,
          current_list_id: @listmonk.list_id,
          current_template_id: @listmonk.template_id
        }
      else
        # Fetch failed - check activity logs for error details
        last_error = ActivityLog.where(target: "newsletter", level: :error).order(created_at: :desc).first
        error_message = last_error&.description || "Failed to fetch lists or templates. Please check your configuration."
        
        render json: {
          success: false,
          error: error_message
        }, status: :unprocessable_entity
      end
    else
      render json: {
        success: false,
        error: "Please configure all required fields first"
      }, status: :unprocessable_entity
    end
  end

  def update
    @listmonk = Listmonk.first_or_initialize
    @activity_logs = ActivityLog.track_activity("newsletter")

    if @listmonk.update(listmonk_params)
      redirect_to admin_newsletter_path, notice: "Newsletter settings updated successfully."
    else
      render :show, alert: @listmonk.errors.full_messages.join(", ")
    end
  end

  private

  def listmonk_params
    params.expect(listmonk: [ :enabled, :username, :api_key, :url, :list_id, :template_id ])
  end

  def verify_params
    params.permit(:username, :api_key, :url, :list_id, :template_id)
  end


end
