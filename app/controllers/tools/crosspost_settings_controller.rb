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
      # Rails.logger.info "Params: #{params.inspect}"

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

      begin
        crosspost_setting = params[:crosspost_setting]

        unless crosspost_setting[:platform] == params[:id]
          raise "Platform mismatch: #{crosspost_setting[:platform]} != #{params[:id]}"
        end

        success = case crosspost_setting[:platform]
        when "mastodon"
          MastodonService.new(nil).verify(crosspost_setting)
        when "twitter"
          TwitterService.new(nil).verify(crosspost_setting)
        when "bluesky"
          # Set default server_url if not provided
          crosspost_setting[:server_url] = "https://bsky.social/xrpc" if crosspost_setting[:server_url].blank?
          BlueskyService.new(nil).verify(crosspost_setting)
        else
          raise "Unknown platform: #{crosspost_setting[:platform]}"
        end

        if success
          render json: { status: "success", message: "#{crosspost_setting[:platform].capitalize} credentials verified successfully!" }
        else
          render json: { status: "error", message: "Failed to verify #{crosspost_setting[:platform].capitalize} credentials." }
        end
      rescue => e
        Rails.logger.error "Verification error for #{params[:id]}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { status: "error", message: "Error: #{e.message}" }, status: :unprocessable_entity
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
