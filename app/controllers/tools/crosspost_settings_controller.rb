module Tools
  class CrosspostSettingsController < ApplicationController
    def index
      @mastodon = CrosspostSetting.mastodon
      @twitter = CrosspostSetting.twitter
    end

    def update
      @setting = CrosspostSetting.find_or_create_by(platform: params[:id])
      Rails.logger.info "Updating CrosspostSetting: #{params[:id]}"
      Rails.logger.info "Params: #{params.inspect}"
      
      if @setting.update(crosspost_setting_params)
        Rails.logger.info "Successfully updated CrosspostSetting"
        redirect_to tools_crosspost_settings_path, notice: 'CrossPost settings updated successfully.'
      else
        Rails.logger.error "Failed to update CrosspostSetting: #{@setting.errors.full_messages}"
        redirect_to tools_crosspost_settings_path, alert: @setting.errors.full_messages.join(', ')
      end
    end

    def verify
      @setting = CrosspostSetting.find_by!(platform: params[:id])
      
      success = case @setting.platform
      when 'mastodon'
        verify_mastodon(@setting)
      when 'twitter'
        verify_twitter(@setting)
      end

      if success
        render json: { status: 'success', message: "#{@setting.platform.capitalize} credentials verified successfully!" }
      else
        render json: { status: 'error', message: "Failed to verify #{@setting.platform.capitalize} credentials." }
      end
    end

    private

    def verify_mastodon(setting)
      return false if setting.server_url.blank? || setting.access_token.blank?
      
      client = Mastodon::REST::Client.new(
        base_url: setting.server_url,
        bearer_token: setting.access_token
      )
      client.verify_credentials
      true
    rescue => e
      Rails.logger.error "Mastodon verification failed: #{e.message}"
      false
    end

    def verify_twitter(setting)
      return false if setting.client_id.blank? || setting.client_secret.blank? || setting.access_token.blank?
      
      client = Twitter::REST::Client.new do |config|
        config.consumer_key = setting.client_id
        config.consumer_secret = setting.client_secret
        config.access_token = setting.access_token
      end
      client.verify_credentials
      true
    rescue => e
      Rails.logger.error "Twitter verification failed: #{e.message}"
      false
    end

    def crosspost_setting_params
      params.require(:crosspost_setting).permit(
        :platform, :server_url, :access_token, 
        :client_id, :client_secret, :enabled
      )
    end
  end
end
