# ensure the working dir is correct
Dir.chdir File.dirname(File.dirname(File.realpath(__FILE__)))

# release file are encrypted and stored in a different directory
if File.directory?(Dir.pwd + '/lib/rcs-worker-release')
  require_relative 'rcs-worker-release/db.rb'
# otherwise we are using development code
elsif File.directory?(Dir.pwd + '/lib/rcs-worker')
  puts "WARNING: Executing clear text code... (debug only)"
  require_relative 'rcs-worker/worker.rb'
else
  puts "FATAL: cannot find any rcs-worker code!"
end
