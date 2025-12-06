module AdminHelper
  def pending_comments_count
    @pending_comments_count ||= Comment.pending.count
  end
end
