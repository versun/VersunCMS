class Admin::SubscribersController < Admin::BaseController
  def index
    @status = params[:status].presence || "all"
    @tag_ids = Array(params[:tag_ids]).reject(&:blank?).map(&:to_i)
    @include_all = params[:include_all].to_s == "1"
    @tags = Tag.alphabetical

    scope = Subscriber.all
    scope = apply_status_filter(scope)
    scope = apply_subscription_filter(scope)

    @subscribers = scope.includes(:tags).order(created_at: :desc).paginate(page: params[:page], per_page: 30)
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
      ActivityLog.log!(
        action: :created,
        target: :subscriber,
        level: error_count > 0 ? :warn : :info,
        success_count: success_count,
        error_count: error_count,
        errors: errors.any? ? errors.join("; ") : nil
      )
      notice = "成功添加 #{success_count} 个订阅者。"
      notice += " #{error_count} 个失败。" if error_count > 0
      redirect_to admin_subscribers_path, notice: notice
    else
      ActivityLog.log!(
        action: :failed,
        target: :subscriber,
        level: :error,
        error_count: error_count,
        errors: errors.join("; ")
      )
      redirect_to admin_subscribers_path, alert: "添加失败: #{errors.join('; ')}"
    end
  end

  def destroy
    @subscriber = Subscriber.find(params[:id])
    email = @subscriber.email
    @subscriber.destroy
    ActivityLog.log!(
      action: :deleted,
      target: :subscriber,
      level: :info,
      email: email
    )
    redirect_to admin_subscribers_path, notice: "订阅者已删除。"
  end

  def batch_confirm
    ids = Array(params[:ids]).reject(&:blank?)
    count = 0

    ids.each do |id|
      subscriber = Subscriber.find_by(id: id)
      next unless subscriber
      next if subscriber.active?

      attrs = {}
      attrs[:confirmed_at] = Time.current unless subscriber.confirmed?
      attrs[:unsubscribed_at] = nil if subscriber.unsubscribed?

      next if attrs.blank?
      count += 1 if subscriber.update(attrs)
    end

    ActivityLog.log!(
      action: :updated,
      target: :subscriber,
      level: :info,
      count: count
    )
    redirect_to admin_subscribers_path, notice: "已确认 #{count} 个订阅者。"
  rescue => e
    ActivityLog.log!(
      action: :failed,
      target: :subscriber,
      level: :error,
      error: e.message
    )
    redirect_to admin_subscribers_path, alert: "批量确认失败: #{e.message}"
  end

  def batch_destroy
    ids = Array(params[:ids]).reject(&:blank?)
    count = 0

    ids.each do |id|
      subscriber = Subscriber.find_by(id: id)
      next unless subscriber

      subscriber.destroy
      count += 1
    end

    ActivityLog.log!(
      action: :deleted,
      target: :subscriber,
      level: :info,
      count: count
    )
    redirect_to admin_subscribers_path, notice: "已删除 #{count} 个订阅者。"
  rescue => e
    ActivityLog.log!(
      action: :failed,
      target: :subscriber,
      level: :error,
      error: e.message
    )
    redirect_to admin_subscribers_path, alert: "批量删除失败: #{e.message}"
  end

  private

  def apply_status_filter(scope)
    case @status
    when "active"
      scope.where.not(confirmed_at: nil).where(unsubscribed_at: nil)
    when "unconfirmed"
      scope.where(confirmed_at: nil)
    when "unsubscribed"
      scope.where.not(confirmed_at: nil).where.not(unsubscribed_at: nil)
    else
      scope
    end
  end

  def apply_subscription_filter(scope)
    return scope if @tag_ids.blank? && !@include_all

    if @tag_ids.any? && @include_all
      scope.left_joins(:tags).where("tags.id IN (?) OR tags.id IS NULL", @tag_ids).distinct
    elsif @tag_ids.any?
      scope.joins(:tags).where(tags: { id: @tag_ids }).distinct
    else
      scope.left_joins(:tags).where(tags: { id: nil })
    end
  end
end
