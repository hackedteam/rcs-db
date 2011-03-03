source "http://rubygems.org"
# Add dependencies required to use your gem here.

gem 'eventmachine'
git "git://github.com/alor/evma_httpserver.git", :branch => "master" do
  gem 'eventmachine_httpserver', ">= 0.2.2"
end
gem 'sqlite3-ruby'
gem 'uuidtools'
#gem 'rcs-common', ">= 0.1.4"
gem 'ffi'

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem "bundler", "~> 1.0.0"
  gem "jeweler", "~> 1.5.2"
  gem "rcov", ">= 0"
  gem 'test-unit'

  gem "rcs-common", :path => "../rcs-common"
end
