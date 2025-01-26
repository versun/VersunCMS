module Tools
  class Export
    # TODO：重构为导出文章为csv格式
    require "zip"

    attr_reader :zip_path, :error_message

    def initialize
      @zip_path = nil
      @error_message = nil
    end

    def generate
        
    end
  end
end
