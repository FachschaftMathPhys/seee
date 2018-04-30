source "http://rubygems.org"

gem "rails", "~>5"
gem "jquery-rails"
gem "jquery-ui-rails"
gem 'bootstrap-datepicker-rails'
gem "sass"
# replaces WebRick to get rid of the content length warnings. See
# http://stackoverflow.com/questions/9612618/
# Also required for multithreaded Rails. See
# http://www.wordchuck.com/en/website/blogs/4
gem "thin"

# rails plugin that allows stripping attributes easily
gem "strip_attributes"

gem "work_queue",      ">=2.0"
gem "open4"
gem "fastimage",	"1.2.13"

# Proper unicode downcase and the like
gem "unicode_utils"

group :production do
end

# Gems used only for assets and not required in production environments
# by default.
  #gem "sass-rails"
  gem "uglifier", ">= 1.0.3"
  gem "therubyracer"
  gem "yui-compressor"

group :test do
  gem "shoulda"
end

# Databases ############################################################
# See http://stackoverflow.com/questions/5769352/ why rails-dbi is
# required
gem "rails-dbi", :require => "dbi"



gem "pg", "~> 0.18"
gem "dbd-pg"

# intended for debugging, but allow for production as well
gem "sqlite3"
gem "dbd-sqlite3"



# Gems only required in Rakefile and/or rakefiles/*
group :rakefiles do
  gem "mechanize" # only used in rakefiles/import.rb
  gem "text" # only used in rakefiles/import.rb via lib/friends.rb
end

# gems required for OMR
group :pest do
  gem "pkg-config"
  gem "cairo"
  gem "glib2", "~> 3.2.1"
  gem 'gtk2'
  gem "rmagick", :require => "RMagick"
end
 gem 'spring', group: :development
gem 'jquery-migrate-rails'
gem 'rails-perftest'
gem 'ruby-prof', '0.15.9'
gem 'jquery-ace-rails'
gem 'coffee-rails'
gem 'jsonapi-resources'
gem "byebug"
