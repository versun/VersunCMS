class AnalyticsController < ApplicationController
  def index
    @total_visits = Ahoy::Visit.count
    events = Ahoy::Event.where(name: "Viewed").where("properties->>'slug' IS NOT NULL")

    # 统计访问量并按数量排序，只取前10篇
    visits_count = {}
    events.each do |event|
      visits_count[event.properties] ||= 0
      visits_count[event.properties] += 1
    end
    @visits_by_path = visits_count.sort_by { |_, count| -count }.first(10).to_h

    # 按引荐来源数量从大到小排序
    @referrers = Ahoy::Visit.group(:referrer)
                            .count
                            .reject { |k, _| k.nil? }
                            .sort_by { |_, count| -count }
                            .to_h

    @browsers = Ahoy::Visit.group(:browser).count
    @operating_systems = Ahoy::Visit.group(:os).count
    @devices = Ahoy::Visit.group(:device_type).count
  end
end
