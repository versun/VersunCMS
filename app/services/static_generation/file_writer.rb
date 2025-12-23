module StaticGeneration
  class FileWriter
    def initialize(output_dir:, rewriter:, event: Rails.event)
      @output_dir = output_dir
      @rewriter = rewriter
      @event = event
    end

    def write(relative_path, content)
      full_path = @output_dir.join(relative_path)
      FileUtils.mkdir_p(File.dirname(full_path))

      if relative_path.end_with?(".html")
        content = @rewriter.rewrite_html(content)
      elsif relative_path == "feed.xml"
        content = @rewriter.rewrite_rss(content)
      end

      File.write(full_path, content)
      @event.notify("static_generator.file_written", level: "debug", component: "StaticGenerator", path: relative_path)
    end
  end
end

