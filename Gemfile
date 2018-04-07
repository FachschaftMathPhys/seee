source "http://rubygems.org"

gem "rails",           "4.0"
gem "jquery-rails", "3.1.4"
gem "jquery-ui-rails"
gem 'bootstrap-datepicker-rails'
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
  gem "sass-rails",   "~> 4.0"
  gem "coffee-rails", "~> 4.0"
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

gem "mysql2"
gem "dbd-mysql"

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
  gem "pkg-config", "1.1.5"
  gem "cairo", "1.12.2"
  gem "glib2", "3.0.8"
  gem "gtk2"
  gem "rmagick", :require => "RMagick"
end
