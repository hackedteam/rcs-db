source "http://rubygems.org"
# Add dependencies required to use your gem here.

gem "rcs-common", ">= 8.1.0", :path => "../rcs-common"

gem 'em-http-request'
gem 'em-websocket'
gem 'em-http-server'

gem 'eventmachine', ">= 1.0.0.beta.4"

# TAR/GZIP compression
gem "minitar", ">= 0.5.5", :git => "git://github.com/danielemilan/minitar.git", :branch => "master"

gem 'rubyzip', ">= 0.9.5"

gem 'bcrypt-ruby'
gem 'plist'
gem 'uuidtools'
gem 'ffi'
# MIME decoding
gem 'mail'
gem 'RocketAMF', :git => "https://github.com/rubyamf/rocketamf.git"

# databases
gem 'mongo', "= 1.6.1", :git => "git://github.com/danielemilan/mongo-ruby-driver.git", :branch => "1.6.1_append"
gem 'mongoid'
gem 'bson', "= 1.6.1"
gem 'bson_ext', "= 1.6.1"

platforms :jruby do
  gem 'json'
  gem 'jruby-openssl'
end

platforms :ruby do
  # to be removed after migration from 7.0
  gem 'mysql2', "= 0.3.3"
  gem 'xml-simple'
end

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem "bundler", "> 1.0.0"
  gem 'rake'
  gem 'test-unit'
end

