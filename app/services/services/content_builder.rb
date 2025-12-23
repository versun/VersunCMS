module Services
  module ContentBuilder
    # 构建社交媒体发布内容
    # @param slug [String] 文章slug（如果提供了article则忽略此参数）
    # @param title [String] 文章标题（如果提供了article则忽略此参数）
    # @param content_text [String] 文章内容（如果提供了article则忽略此参数）
    # @param description_text [String, nil] 文章描述（可选，如果提供了article则忽略此参数）
    # @param article [Article] 文章对象，用于检查source reference和获取文章属性
    # @param max_length [Integer] 最大字符长度限制
    # @param always_add_link [Boolean] 是否总是添加链接（默认false，即根据内容长度判断）
    # @param count_non_ascii_double [Boolean] 是否将非ASCII字符计为2个字符（用于Twitter等平台）
    # @return [String] 构建好的内容
    def build_content(slug = nil, title = nil, content_text = nil, description_text = nil, article: nil, max_length: 300, always_add_link: false, count_non_ascii_double: false)
      # 如果提供了 article 对象，优先使用 article 的属性
      if article
        slug = article.slug
        title = article.title
        content_text = article.plain_text_content
        description_text = article.description
      end

      content_text = description_text.presence || content_text

      # 检查是否有source reference，如果有则在内容末尾添加source URL
      if article&.has_source? && article.source_url.present?
        source_url_text = "\n#{article.source_url}"
        content_text = content_text + source_url_text
      end

      title_length = count_chars(title, count_non_ascii_double)
      content_length = count_chars(content_text, count_non_ascii_double)

      # 检查是否需要添加链接
      total_length = title_length + content_length + 1 # +1 for newline
      needs_link = always_add_link || total_length >= max_length

      # 如果不需要链接，返回完整内容
      return "#{title}\n#{content_text}" unless needs_link

      # 构建URL和链接文本
      post_url = build_post_url(slug)
      link_text = count_non_ascii_double ? "\nRead more:#{post_url}" : "\nRead more: #{post_url}"
      link_length = count_non_ascii_double ? 34 : (count_chars(link_text, false))

      # 计算可用于标题和内容的长度
      available_length = max_length - link_length

      # 如果标题过长，截断标题
      if title_length >= available_length - 3
        return "#{truncate_text(title, available_length - 3, count_non_ascii_double)}...#{link_text}"
      end

      # 计算内容可用长度
      remaining_length = available_length - title_length - 1 # -1 for newline after title

      # 如果没有足够空间放内容，只显示标题和链接
      return "#{title}#{link_text}" if remaining_length <= 4

      # 截断内容并添加省略号
      "#{title}\n#{truncate_text(content_text, remaining_length - 3, count_non_ascii_double)}...#{link_text}"
    end

    # 计算字符数（可选择非ASCII字符计为2）
    # @param str [String] 要计算的字符串
    # @param count_non_ascii_double [Boolean] 是否将非ASCII字符计为2个字符
    # @return [Integer] 字符数
    def count_chars(str, count_non_ascii_double = false)
      return str.length unless count_non_ascii_double

      str.each_char.map { |c| c.ascii_only? ? 1 : 2 }.sum
    end

    # 截断文本到指定长度（支持非ASCII字符计数）
    # @param str [String] 要截断的字符串
    # @param max_length [Integer] 最大长度
    # @param count_non_ascii_double [Boolean] 是否将非ASCII字符计为2个字符
    # @return [String] 截断后的字符串
    def truncate_text(str, max_length, count_non_ascii_double = false)
      return str[0...max_length] unless count_non_ascii_double

      current_length = 0
      chars = []

      str.each_char do |c|
        char_length = c.ascii_only? ? 1 : 2
        break if current_length + char_length > max_length
        current_length += char_length
        chars << c
      end

      chars.join("")
    end

    # 构建文章URL
    # @param slug [String] 文章slug
    # @return [String] 文章完整URL
    def build_post_url(slug)
      # 确保获取完整URL，带scheme
      site_url = Setting.first&.url.presence || "http://localhost:3000"

      # 移除末尾的斜杠
      site_url = site_url.chomp("/")

      # 确保URL有scheme
      site_url = "https://#{site_url}" unless site_url.match?(%r{^https?://})

      # 解析获取host和scheme
      uri = URI.parse(site_url)

      Rails.application.routes.url_helpers.article_url(
        slug,
        host: uri.host,
        protocol: uri.scheme
      )
    end
  end
end
