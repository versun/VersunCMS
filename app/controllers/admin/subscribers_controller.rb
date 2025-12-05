class Admin::SubscribersController < Admin::BaseController
  def index
    @subscribers = Subscriber.order(created_at: :desc).paginate(page: params[:page], per_page: 30)
  end

  def batch_create
    emails_text = params[:emails_text] || ""
    return redirect_to admin_subscribers_path, alert: "请输入邮箱地址。" if emails_text.blank?

    success_count = 0
    error_count = 0
    errors = []

    emails_text.split("\n").each do |line|
      line = line.strip
      next if line.blank?

      # 解析格式：email,tag1,tag2,tag3 或 email
      parts = line.split(",").map(&:strip)
      email = parts[0]
      tag_names = parts[1..-1] || []

      # 验证邮箱格式
      unless email.match?(URI::MailTo::EMAIL_REGEXP)
        error_count += 1
        errors << "无效的邮箱格式: #{email}"
        next
      end

      # 查找或创建订阅者
      subscriber = Subscriber.find_or_initialize_by(email: email)
      is_new = subscriber.new_record?
      
      # 如果是新订阅者，先保存
      unless subscriber.save
        error_count += 1
        errors << "#{email}: #{subscriber.errors.full_messages.join(', ')}"
        next
      end
      
      # 如果是新订阅者，自动确认
      subscriber.confirm! if is_new && !subscriber.confirmed?

      # 处理tags
      if tag_names.any?
        tags = tag_names.map { |name| Tag.find_or_create_by(name: name) }
        subscriber.tags = tags
      else
        # 如果没有指定tags，设为空（订阅所有内容）
        subscriber.tags = []
      end

      if subscriber.save
        success_count += 1
      else
        error_count += 1
        errors << "#{email}: #{subscriber.errors.full_messages.join(', ')}"
      end
    end

    if success_count > 0
      notice = "成功添加 #{success_count} 个订阅者。"
      notice += " #{error_count} 个失败。" if error_count > 0
      redirect_to admin_subscribers_path, notice: notice
    else
      redirect_to admin_subscribers_path, alert: "添加失败: #{errors.join('; ')}"
    end
  end

  def destroy
    @subscriber = Subscriber.find(params[:id])
    @subscriber.destroy
    redirect_to admin_subscribers_path, notice: "订阅者已删除。"
  end
end

