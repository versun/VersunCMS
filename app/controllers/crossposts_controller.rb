class CrosspostsController < ApplicationController
  def index
    @mastodon = Crosspost.mastodon
    @twitter = Crosspost.twitter
    @bluesky = Crosspost.bluesky
    @listmonk = Crosspost.listmonk
  end

  def update
    platforms = %w[mastodon twitter bluesky]

    platforms.each do |platform|
      settings = Crosspost.find_or_create_by(platform: platform)
      platform_params = params[:crosspost][platform]

      if platform_params.present?
        if settings.update(platform_params.permit(:enabled, :platform))
          Rails.logger.info "Successfully updated Crosspost: #{platform}"
        else
          Rails.logger.error "Failed to update Crosspost: #{platform} - #{settings.errors.full_messages}"
          flash[:alert] = settings.errors.full_messages.join(", ")
        end
      end
    end

    redirect_to crossposts_path, notice: "CrossPost 设置已成功更新。"
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

  # def crosspost_params
  #   params.require(:crosspost).permit(
  #     :platform, :enabled
  #   )
  # end
end
