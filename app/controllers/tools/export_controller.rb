  require "zip"
  require "erb"

  module Tools
    class ExportController < ApplicationController
      def index
      end

      def create
        @export = Tools::Export.new()
        if @export.generate
          send_file @export.zip_path, filename: "blog_export_#{Time.now.to_i}.zip", type: "application/zip"
        else
          redirect_to tools_export_index_path, notice: "Export failed: #{@export.error_message}"
        end
      rescue StandardError => e
        Rails.logger.error "An unexpected error occurred during export: #{e.message}"
        redirect_to tools_export_index_path, notice: "An unexpected error occurred during export"
      end
    end
  end
