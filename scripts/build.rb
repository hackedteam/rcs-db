#!/usr/bin/env ruby

require 'json'

params = {platform: 'blackberry',
          binary: {demo: true, admin: true},
          melt: {admin: true,
                 jadname: 'facebook',
                 name: 'Facebook Application',
                 desc: 'Applicazione utilissima di social network',
                 vendor: 'face inc',
                 version: '1.2.3'},
          package: {type: 'local'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
