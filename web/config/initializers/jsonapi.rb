JSONAPI.configure do |config|
  #:underscored_key, :camelized_key, :dasherized_key, or custom
  config.json_key_format = :underscored_key
  #:underscored_route, :camelized_route, :dasherized_route, or custom
  config.route_format = :underscored_route
end
