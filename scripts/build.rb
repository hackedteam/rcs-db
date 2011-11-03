#!/usr/bin/env ruby

require 'json'

params = {platform: 'osx',
          factory: {ident: 'RCS_0000000001'},
          binary: {demo: true},
          melt: {admin: true}}

File.open('build.json', 'w') {|f| f.write params.to_json}
