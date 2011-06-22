require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "rcs-db"
  gem.homepage = "http://rcs-dev/cgi-bin/gitweb.cgi?p=rcs-db.git"
  gem.license = "MIT"
  gem.summary = %Q{The RCS Database}
  gem.description = %Q{This is where all the evidence are stored and analyzed}
  gem.email = "alor@hackingteam.it"
  gem.authors = ["ALoR"]
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test


def execute(message)
  print message + '...'
  STDOUT.flush
  if block_given? then
    yield
  end
  puts ' ok'
end


desc "Housekeeping for the project"
task :clean do
  execute "Cleaning the log directory" do
    Dir['./log/*'].each do |f|
      File.delete(f)
    end
  end
end

desc "Create the NSIS installer for windows"
task :nsis do
  puts "Housekeeping..."
  Rake::Task[:clean].invoke
  execute "Creating NSIS installer" do
    # invoke the nsis builder
    system "\"C:\\Program Files (x86)\\NSIS\\makensis.exe\" /V2 ./nsis/RCSDB.nsi"
  end
end

desc "Remove the protected release code"
task :unprotect do
  execute "Deleting the protected release folder" do
    FileUtils.rm_rf(Dir.pwd + '/lib/rgloader') if File.exist?(Dir.pwd + '/lib/rgloader')
    FileUtils.rm_rf(Dir.pwd + '/lib/rcs-db-release') if File.exist?(Dir.pwd + '/lib/rcs-db-release')
    FileUtils.rm_rf(Dir.pwd + '/lib/rcs-worker-release') if File.exist?(Dir.pwd + '/lib/rcs-worker-release')
  end
end

RUBYENCPATH = '/Applications/Development/RubyEncoder'

desc "Create the encrypted code for release"
task :protect do
  Rake::Task[:unprotect].invoke
  execute "Creating release folder" do
    Dir.mkdir(Dir.pwd + '/lib/rcs-db-release') if not File.directory?(Dir.pwd + '/lib/rcs-db-release')
    Dir.mkdir(Dir.pwd + '/lib/rcs-worker-release') if not File.directory?(Dir.pwd + '/lib/rcs-worker-release')
  end
  execute "Copying the rgloader" do
    RGPATH = RUBYENCPATH + '/rgloader'
    Dir.mkdir(Dir.pwd + '/lib/rgloader')
    files = Dir[RGPATH + '/*']
    # keep only the interesting files (1.9.2 windows, macos, linux)
    files.delete_if {|v| v.match(/rgloader\./)}
    files.delete_if {|v| v.match(/19[\.1]/)}
    files.delete_if {|v| v.match(/bsd/)}
    files.each do |f|
      FileUtils.cp(f, Dir.pwd + '/lib/rgloader')
    end
  end
  execute "Encrypting code" do
    # we have to change the current dir, otherwise rubyencoder
    # will recreate the lib/rcs-collector structure under rcs-collector-release
    Dir.chdir "lib/rcs-db/"
    system "#{RUBYENCPATH}/bin/rubyencoder -o ../rcs-db-release -r --ruby 1.9.2 *.rb */*.rb"
    Dir.chdir "../rcs-worker"
    system "#{RUBYENCPATH}/bin/rubyencoder -o ../rcs-worker-release -r --ruby 1.9.2 *.rb */*.rb"
    Dir.chdir "../.."
  end
end

