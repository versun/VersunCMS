module Tools
  class CrosspostSettingsController < ApplicationController
    def index
      @mastodon = CrosspostSetting.mastodon
      @twitter = CrosspostSetting.twitter
      @bluesky = CrosspostSetting.bluesky
    end

    def update
      @settings = CrosspostSetting.find_or_create_by(platform: params[:id])
      Rails.logger.info "Updating CrosspostSetting: #{params[:id]}"
      Rails.logger.info "Params: #{params.inspect}"

      if @settings.update(crosspost_setting_params)
        Rails.logger.info "Successfully updated CrosspostSetting"
        redirect_to tools_crosspost_settings_path, notice: "CrossPost settings updated successfully."
      else
        Rails.logger.error "Failed to update CrosspostSetting: #{@settings.errors.full_messages}"
        redirect_to tools_crosspost_settings_path, alert: @settings.errors.full_messages.join(", ")
      end
    end

    def verify
      Rails.logger.info "Verifying #{params[:id]} platform"
      Rails.logger.info "Params: #{params.inspect}"
      
      @settings = CrosspostSetting.find_by!(platform: params[:id])

      success = case @settings.platform
      when "mastodon"
        
        MastodonService.verify(@settings)
      when "twitter"
        TwitterService.verify(@settings)
      when "bluesky"
        BlueskyService.verify(@settings)
      end

      if success
        render json: { status: "success", message: "#{@settings.platform.capitalize} credentials verified successfully!" }
      else
        render json: { status: "error", message: "Failed to verify #{@settings.platform.capitalize} credentials." }
      end
    end

    private

    def crosspost_setting_params
      params.require(:crosspost_setting).permit(
        :platform, :server_url, :access_token, :access_token_secret,
        :client_id, :client_secret, :enabled
      )
    end
  end
end
