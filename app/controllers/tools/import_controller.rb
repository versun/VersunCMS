require "zip"
require "json"
require "nokogiri"
require "uri"
require "net/http"

module Tools
  class ImportController < ApplicationController
    include ActiveStorage::SetCurrent

    def index
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
      @import = RssImport.new(params[:file])
      if @import.import_data
        redirect_to tools_import_index_path, notice: "RSS Import successful"
      else
        redirect_to tools_import_index_path, alert: "RSS Import failed: #{@import.error_message}"
      end
    rescue StandardError => e
      Rails.logger.error "RSS Import error: #{e.message}"
      redirect_to tools_import_index_path, alert: "An unexpected error occurred during RSS import"
    ensure
      refresh_pages
      refresh_settings
    end
  end
end
