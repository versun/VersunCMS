class CrosspostsController < ApplicationController
  def index
    @mastodon = Crosspost.mastodon
    @twitter = Crosspost.twitter
    @bluesky = Crosspost.bluesky
    @listmonk = Crosspost.listmonk
  end

  def update
    @settings = Crosspost.find_or_create_by(platform: params[:id])
    Rails.logger.info "Updating Crosspost: #{params[:id]}"
    # Rails.logger.info "Params: #{params.inspect}"

    if @settings.update(crosspost_params)
      Rails.logger.info "Successfully updated Crosspost"
      redirect_to crossposts_path, notice: "CrossPost settings updated successfully."
    else
      Rails.logger.error "Failed to update Crosspost: #{@settings.errors.full_messages}"
      redirect_to crossposts_path, alert: @settings.errors.full_messages.join(", ")
    end
  end


  def verify
    begin
      platform = params[:id]
      #platform_params = params.require(:crosspost).require(platform).permit(:enabled)

      results = case platform
                when "mastodon" then Integrations::MastodonService.new.verify
                when "twitter" then Integrations::TwitterService.new.verify
                when "bluesky" then Integrations::BlueskyService.new.verify
                else raise "Unknown: #{platform}"
                end

      if results[:success]
        render json: { status: "success", message: "Verified Successfully!" }
      else
        render json: { status: "error", message: results[:error] }
      end
    rescue => e
      Rails.logger.error "Verification error for #{platform}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { status: "error", message: "Error: #{e.message}" }, status: :unprocessable_entity
    end
  end

  private

  def crosspost_params
    params.require(:crosspost).permit(
      :platform, :enabled
    )
  end
end
