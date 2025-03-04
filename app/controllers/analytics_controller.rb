class AnalyticsController < ApplicationController
  def index
    @total_visits = Ahoy::Visit.count
    events = Ahoy::Event.where(name: "Viewed").where("properties->>'slug' IS NOT NULL")
    @visits_by_path = {}
    events.each do |event|
      @visits_by_path[event.properties] ||= 0
      @visits_by_path[event.properties] += 1
    end

    @referrers = Ahoy::Visit.group(:referrer).count.reject { |k, _| k.nil? }
    @browsers = Ahoy::Visit.group(:browser).count
    @operating_systems = Ahoy::Visit.group(:os).count
    @devices = Ahoy::Visit.group(:device_type).count
  end
end
