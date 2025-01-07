require "zip"
require "json"
require "nokogiri"
require "uri"
require "net/http"

module Tools
  class ImportController < ApplicationController
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

      @import = Tools::DBImport.new
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

    def from_wordpress
      @import = Tools::WordPressImport.new(params[:file])
      if @import.process
        redirect_to tools_import_index_path, notice: "WordPress导入成功"
      else
        redirect_to tools_import_index_path, alert: "导入失败: #{@import.error_message}"
      end
    rescue StandardError => e
      Rails.logger.error "WordPress导入错误: #{e.message}"
      redirect_to tools_import_index_path, alert: "导入过程中发生意外错误，请联系管理员"
    ensure
      refresh_pages
      refresh_settings
    end
  end
end
