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

      content = content.to_s
      unless content.encoding == Encoding::UTF_8
        begin
          content = content.encode(Encoding::UTF_8)
        rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
          content = content.dup.force_encoding(Encoding::UTF_8)
        end
      end
      File.binwrite(full_path, content)
      @event.notify("static_generator.file_written", level: "debug", component: "StaticGenerator", path: relative_path)
    end
  end
end
