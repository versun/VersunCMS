class Ahoy::Store < Ahoy::DatabaseStore
end

# set to true for JavaScript tracking
Ahoy.api = false

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = false

Ahoy.visit_duration = 30.minutes
Ahoy.visitor_duration = 30.days

Ahoy.track_bots = true
Ahoy.server_side_visits = false # 禁用服务器端访问记录