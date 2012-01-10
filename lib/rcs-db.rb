# ensure the working dir is correct
Dir.chdir File.dirname(File.dirname(File.realpath(__FILE__)))

# load the bundler gem (those taken from git and not installed in rubygems)
#Bundler.setup

# release file are encrypted and stored in a different directory
if File.directory?(Dir.pwd + '/lib/rcs-db-release')
  require_relative 'rcs-db-release/migration'
  require_relative 'rcs-db-release/db'
# otherwise we are using development code
elsif File.directory?(Dir.pwd + '/lib/rcs-db')
  puts "WARNING: Executing clear text code... (debug only)"
  require_relative 'rcs-db/migration'
  require_relative 'rcs-db/db'
else
  puts "FATAL: cannot find any rcs-db code!"
end
