# app/helpers/settings_helper.rb
module SettingsHelper
  def timezone_options
    ActiveSupport::TimeZone.all.map do |zone|
      current_time = Time.current.in_time_zone(zone)
      # Format: "2024/01/25 14:30 - (UTC+08:00) Beijing"
      [
        "#{current_time.strftime('%Y/%m/%d %H:%M')} - (#{zone.formatted_offset}) #{zone.name}",
        zone.name
      ]
    end
  end
end
