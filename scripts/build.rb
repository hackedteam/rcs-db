#!/usr/bin/env ruby

require 'json'

params = {platform: 'symbian',
          factory: {ident: 'RCS_0000000001'},
          binary: {demo: true}}

File.open('build.json', 'w') {|f| f.write params.to_json}
