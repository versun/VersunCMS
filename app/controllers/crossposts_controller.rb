class CrosspostsController < ApplicationController
  def index
    @mastodon = Crosspost.mastodon
    @twitter = Crosspost.twitter
    @bluesky = Crosspost.bluesky
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
    Rails.logger.info "Verifying #{params[:id]} platform"
    Rails.logger.info "Params: #{params.inspect}"

    begin
      crosspost = params[:crosspost]

      unless crosspost[:platform] == params[:id]
        raise "Platform mismatch: #{crosspost[:platform]} != #{params[:id]}"
      end

      results = case crosspost[:platform]
      when "mastodon"
        Integrations::MastodonService.new(nil).verify(crosspost)
      when "twitter"
        Integrations::TwitterService.new(nil).verify(crosspost)
      when "bluesky"
        # Set default server_url if not provided
        crosspost[:server_url] = "https://bsky.social/xrpc" if crosspost[:server_url].blank?
        Integrations::BlueskyService.new(nil).verify(crosspost)
      else
        raise "Unknown platform: #{crosspost[:platform]}"
      end

      if results[:success]
        render json: { status: "success", message: "Verified Successfully!" }
      else
        render json: { status: "error", message: results[:error] }
      end
    rescue => e
      Rails.logger.error "Verification error for #{params[:id]}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { status: "error", message: "Error: #{e.message}" }, status: :unprocessable_entity
    end
  end

  private

  def crosspost_params
    params.require(:crosspost).permit(
      :platform, :server_url, :access_token, :access_token_secret,
      :client_id, :client_secret, :enabled
    )
  end
end
