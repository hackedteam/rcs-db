# ensure the working dir is correct
Dir.chdir File.dirname(File.dirname(File.realpath(__FILE__)))

# release file are encrypted and stored in a different directory
if File.directory?(Dir.pwd + '/lib/rcs-db-release')
  require_relative 'rcs-db-release/db.rb'
# otherwise we are using development code
elsif File.directory?(Dir.pwd + '/lib/rcs-db')
  puts "WARNING: Executing clear text code... (debug only)"
  require_relative 'rcs-db/db.rb'
else
  puts "FATAL: cannot find any rcs-db code!"
end
