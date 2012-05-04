source "http://rubygems.org"
# Add dependencies required to use your gem here.

gem "rcs-common", ">= 8.0.0", :path => "../rcs-common"


gem 'em-http-request'
gem 'em-websocket'
#git "git://github.com/alor/eventmachine.git", :branch => "master" do
  gem 'eventmachine', ">= 1.0.0.beta.4"
#end
git "git://github.com/alor/evma_httpserver.git", :branch => "master" do
  gem 'eventmachine_httpserver', ">= 0.2.2"
end

# TAR/GZIP compression
git "git://github.com/danielemilan/minitar.git", :branch => "master" do
  gem "minitar", ">= 0.5.5"
end
gem 'rubyzip', ">= 0.9.5"
gem 'bcrypt-ruby'
gem 'plist'
gem 'uuidtools'
gem 'ffi'
# MIME decoding
gem 'mail'
gem 'RocketAMF', :git => "https://github.com/rubyamf/rocketamf.git"

# databases
gem 'mongo', :git => "git://github.com/danielemilan/mongo-ruby-driver.git"
gem 'mongoid'
gem 'bson'
gem 'bson_ext', ">= 1.6.2"
# to be removed after migration from 7.0
gem 'mysql2', "= 0.3.3"
gem 'xml-simple'

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem "bundler", "> 1.0.0"
  gem 'rake'
  gem 'test-unit'
end

