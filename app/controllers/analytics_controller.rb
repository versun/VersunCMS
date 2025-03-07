class AnalyticsController < ApplicationController
  allow_unauthenticated_access only: %i[ index ]

  def index
    @total_visits = Ahoy::Visit.count
    events = Ahoy::Event.where(name: "Viewed").where("properties->>'slug' IS NOT NULL")

    # 统计访问量并按数量排序，只取前20篇
    visits_count = {}
    events.each do |event|
      visits_count[event.properties] ||= 0
      visits_count[event.properties] += 1
    end
    @visits_by_path = visits_count.sort_by { |_, count| -count }.first(20).to_h

    @referrers = Ahoy::Visit.group(:referrer)
                            .count
                            .reject { |k, _| k.nil? }
                            .sort_by { |_, count| -count }
                            .first(20)
                            .to_h

    @browsers = Ahoy::Visit.group(:browser)
                           .count
                           .sort_by { |_, count| -count }
                           .to_h

    @operating_systems = Ahoy::Visit.group(:os)
                                    .count
                                    .sort_by { |_, count| -count }
                                    .to_h

    @devices = Ahoy::Visit.group(:device_type)
                          .count
                          .sort_by { |_, count| -count }
                          .to_h
  end
end
