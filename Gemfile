source "http://rubygems.org"
# Add dependencies required to use your gem here.

gem 'eventmachine', "~> 1.0.0.beta.3"
git "git://github.com/alor/evma_httpserver.git", :branch => "master" do
  gem 'eventmachine_httpserver', ">= 0.2.2"
end
gem 'uuidtools'
#gem 'rcs-common', ">= 0.1.4"
gem 'ffi'

# remove this after migration is complete
gem 'em-proxy'
gem 'em-http-request'

# databases
gem 'sqlite3'
gem 'mongo'
gem 'mongoid'
gem 'bson'
gem 'bson_ext'
gem 'mysql2', :git => "https://github.com/brianmario/mysql2.git", :branch => "master"
gem 'xml-simple'

# UUID generation
gem 'guid'

# MIME decoding
gem 'mail'

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem "bundler", "~> 1.0.0"
  gem "jeweler", "~> 1.5.2"
  gem "rcov", ">= 0"
  gem 'test-unit'
  
  gem "rcs-common", :path => "../rcs-common"
end
