class PublishScheduledArticlesJob < ApplicationJob
  queue_as :urgent
  queue_with_priority 10

  def perform(article_id)
    article = Article.find(article_id)
    Rails.logger.info "Publishing scheduled article #{article_id} at #{Time.current}"
    article.publish_scheduled
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Failed to find article #{article_id} for scheduled publishing: #{e.message}")
  end

  def self.schedule_at(article)
    return unless article.schedule? && article.scheduled_at.present?

    # The scheduled_at value is already in UTC in the database
    # We only need to convert it to the application time zone for display/job scheduling
    scheduled_time = article.scheduled_at # UTC

    set(wait_until: scheduled_time).perform_later(article.id)

    Rails.logger.info "Scheduled article #{article.id} for publication at #{scheduled_time}"
  end

  private

  # def self.scheduled_job_for(article)
  #   ActiveJob::Base.queue_adapter.enqueued_jobs.find do |job|
  #     job[:job] == self && job[:args].first == article.id
  #   end
  # end
end
