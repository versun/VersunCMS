module Tools
  class CrosspostSettingsController < ApplicationController
    layout 'tools'

    def index
      @mastodon = CrosspostSetting.mastodon
      @twitter = CrosspostSetting.twitter
      render 'index'
    end

    def update
      @setting = CrosspostSetting.find_by!(platform: params[:id])
      
      if @setting.update(crosspost_setting_params)
        redirect_to tools_crosspost_settings_path, notice: 'CrossPost settings updated successfully.'
      else
        redirect_to tools_crosspost_settings_path, alert: @setting.errors.full_messages.join(', ')
      end
    end

    private

    def crosspost_setting_params
      params.require(:crosspost_setting).permit(
        :platform, :server_url, :access_token, 
        :client_id, :client_secret, :enabled
      )
    end
  end
end
