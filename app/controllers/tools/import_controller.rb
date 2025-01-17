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

    def from_db
      if params[:file].nil?
        redirect_to tools_import_index_path, alert: "Please select a backup file"
        return
      end

      unless params[:file].content_type == "application/zip"
        redirect_to tools_import_index_path, alert: "Invalid file type. Please upload a zip file"
        return
      end

      @import = Tools::DbImport.new
      if @import.restore(params[:file].tempfile.path)
        redirect_to tools_import_index_path, notice: "Database restored successfully"
      else
        redirect_to tools_import_index_path, alert: "Restore failed: #{@import.error_message}"
      end
    rescue StandardError => e
      Rails.logger.error "Database restore error: #{e.message}"
      redirect_to tools_import_index_path, alert: "An unexpected error occurred during restore"
    ensure
      refresh_pages
      refresh_settings
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
