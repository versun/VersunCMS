require "zip"
require "json"
require "nokogiri"
require "uri"
require "net/http"

module Tools
  class ImportController < ApplicationController
    include ActiveStorage::SetCurrent

    def index
      @activity_logs = ActivityLog.track_activity("import")
    end

    def from_rss
      RssImportJob.perform_later(params[:url], params[:import_images])
      redirect_to tools_import_index_path, notice: "RSS Import in progress, please check the logs for details"
    rescue StandardError => e
      Rails.logger.error "RSS Import error: #{e.message}"
      redirect_to tools_import_index_path, alert: "An unexpected error occurred during RSS import"
    end
  end
end
