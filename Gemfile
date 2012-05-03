source "http://rubygems.org"
# Add dependencies required to use your gem here.

gem "rcs-common", ">= 8.0.0", :path => "../rcs-common"

gem 'eventmachine', ">= 1.0.0.beta.4"
gem 'em-http-request'
gem 'em-websocket'
gem 'em-http-server'

gem "minitar", ">= 0.5.5", :git => "git://github.com/danielemilan/minitar.git"

gem 'rubyzip'
gem 'bcrypt-ruby'
gem 'plist'
gem 'uuidtools'
gem 'ffi'
# MIME decoding
gem 'mail'
#gem 'RocketAMF', :git => "https://github.com/rubyamf/rocketamf.git"

# databases
gem 'mongo', :git => "git://github.com/danielemilan/mongo-ruby-driver.git"
gem 'mongoid'
gem 'bson'
#gem 'bson_ext', ">= 1.6.2"

platforms :jruby do
  gem 'json'
  gem 'jruby-openssl'
end

platforms :ruby do
  # remove after migration
  gem 'mysql2'
  gem 'xml-simple'
end

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem "bundler", "> 1.0.0"
  gem 'rake'
  gem 'test-unit'
end

