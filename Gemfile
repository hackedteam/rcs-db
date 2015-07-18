source "http://rubygems.org"
# Add dependencies required to use your gem here.

gem "rcs-common", ">= 9.2.3", :path => "../rcs-common"

gem 'em-http-request', "=1.0.3" # > 1.0.3 version does not work under Windows
gem 'em-websocket'
gem 'em-http-server', ">= 0.1.7"

gem 'eventmachine', ">= 1.0.3"

# TAR/GZIP compression
gem "minitar", ">= 0.5.5", :git => "git://github.com/danielemilan/minitar.git", :branch => "master"

gem 'rubyzip', '= 1.0.0'
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
gem 'mongoid', ">= 3.0.0"
gem 'rvincenty'
gem 'colorize'

gem 'ruby-opencv', "~> 0.0.10"
# Install the 2.4.4a version via homebrew, and then launch if your homebrew folder
# is not in the default location, lauch:
# gem install ruby-opencv -v 0.0.10 -- --with-opencv-dir="/Users/username/.homebrew/Cellar/opencv/2.4.4a"
# check this out: http://stackoverflow.com/questions/3987683/homebrew-install-specific-version-of-formula
gem 'tuple', :git => 'https://github.com/topac/tuple.git'
gem 'sbdb'
# needs some love to compile bdb and tuple under windows
# see scripts/coins/INSTALL

gem 'bitcoin-ruby'

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
