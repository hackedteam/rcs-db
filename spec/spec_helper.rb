# require 'json'
require 'bundler'
require 'pry'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
	
def require_db(file)
  relative_path_to_db = 'lib/rcs-db/'
  relative_path_file = File.join(Dir.pwd, relative_path_to_db, file)

  if File.exist?(relative_path_file) or File.exist?(relative_path_file + ".rb")
    require_relative relative_path_file
  else
    raise "Could not load #{file}"
  end
end
