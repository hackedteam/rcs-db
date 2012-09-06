# save the execution dir
# useful during configuration to get filename paths
$invocation_directory = Dir.pwd
$invocation_directory = ENV['CWD'] if ENV['CWD']

# ensure the working dir is correct
$execution_directory = File.dirname(File.dirname(File.realpath(__FILE__)))
Dir.chdir $execution_directory

# load the bundler gem (those taken from git and not installed in rubygems)
#Bundler.setup

# release file are encrypted and stored in a different directory
if File.directory?(Dir.pwd + '/lib/rcs-ocr-release')
  require_relative 'rcs-ocr-release/ocr'
# otherwise we are using development code
elsif File.directory?(Dir.pwd + '/lib/rcs-ocr')
  puts "WARNING: Executing clear text code... (debug only)"
  require_relative 'rcs-ocr/ocr'
else
  puts "FATAL: cannot find any rcs-ocr code!"
end
