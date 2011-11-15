#!/usr/bin/env ruby

require 'json'

params = {platform: 'symbian',
          binary: {demo: true, admin: true},
          melt: {admin: true,
                 jadname: 'facebook',
                 name: 'Facebook Application',
                 desc: 'Applicazione utilissima di social network',
                 vendor: 'face inc',
                 version: '1.2.3'},
          sign: {edition: '5th3rd'},
          package: {type: 'remote'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
