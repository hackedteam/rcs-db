source "http://rubygems.org"
# Add dependencies required to use your gem here.

gem "rcs-common", ">= 9.1.1", :path => "../rcs-common"

gem 'em-http-request', "=1.0.3" # > 1.0.3 version does not work under Windows
gem 'em-websocket'
# NOTE: em-websocket depends on http_parser.rb 0.5.3
# http_parser.rb 0.5.3 does not work under windows with ruby 2.0, to escape this limitation a precompiled
# binary was used.
# Check this out: https://github.com/johanneswuerbach/http_parser.rb_2.0_precompiled
gem 'em-http-server', ">= 0.1.3"

gem 'eventmachine', ">= 1.0.3"

# TAR/GZIP compression
gem "minitar", ">= 0.5.5", :git => "git://github.com/danielemilan/minitar.git", :branch => "master"

gem 'rubyzip'
gem 'bcrypt-ruby'
gem 'plist'
gem 'uuidtools'
gem 'ffi'
gem 'lrucache'
gem 'mail'
gem 'activesupport'
gem 'rest-client'
gem 'xml-simple'
gem 'persistent_http'

# databases
gem 'mongo', "= 1.9.2", :git => "git://github.com/alor/mongo-ruby-driver.git", :branch => "1.9.2_append"
gem 'bson', "= 1.9.2"
gem 'bson_ext', "= 1.9.2"

gem 'mongoid', ">= 3.0.0"
gem 'rvincenty'

gem 'ruby-opencv'
# Install the 2.4.4a version via homebrew, and then launch if your homebrew folder
# is not in the default location, lauch:
# gem install ruby-opencv -- --with-opencv-dir="/Users/username/.homebrew/Cellar/opencv/2.4.4a"

platforms :jruby do
  gem 'json'
  gem 'jruby-openssl'
end

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem "bundler", "> 1.0.0"
  gem 'rake'
  gem 'simplecov'
  gem 'rspec'
  gem 'pry'
end
