module Tools
  class ExportController < ApplicationController
    def index
    end

    def create
      export_tool = Tools::Export.new
      csv_data = export_tool.generate_csv

      if csv_data
        send_data csv_data,
                  filename: "articles_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: "text/csv",
                  disposition: "attachment"
      else
        flash[:error] = export_tool.error_message || "导出失败"
        redirect_to tools_export_index_path
      end
    end
  end
end
