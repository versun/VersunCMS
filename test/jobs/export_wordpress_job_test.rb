require "test_helper"

class ExportWordpressJobTest < ActiveJob::TestCase
  test "should create activity log on success" do
    # 创建一个mock的WordpressExport实例
    mock_exporter = Minitest::Mock.new
    mock_exporter.expect :generate, true
    mock_exporter.expect :export_path, "/tmp/test_export.xml"
    
    # 模拟文件存在
    File.stub :exist?, true do
      File.stub :mv, true do
        WordpressExport.stub :new, mock_exporter do
          assert_enqueued_with(job: ExportWordpressJob) do
            ExportWordpressJob.perform_later
          end
          
          perform_enqueued_jobs do
            ExportWordpressJob.perform_later
          end
          
          # 检查是否创建了活动日志
          assert_equal 1, ActivityLog.where(target: "wordpress_export", action: "initiated").count
        end
      end
    end
    
    mock_exporter.verify
  end

  test "should create error activity log on failure" do
    # 创建一个会失败的mock
    mock_exporter = Minitest::Mock.new
    mock_exporter.expect :generate, false
    mock_exporter.expect :error_message, "Test error"
    
    WordpressExport.stub :new, mock_exporter do
      perform_enqueued_jobs do
        ExportWordpressJob.perform_later
      end
      
      # 检查是否创建了错误活动日志
      error_logs = ActivityLog.where(target: "wordpress_export", action: "failed")
      assert error_logs.exists?
      assert error_logs.first.description.include?("Test error")
    end
    
    mock_exporter.verify
  end
end