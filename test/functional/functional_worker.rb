require_relative 'helper'

require 'rcs-common/evidence_manager'

require 'eventmachine'
require 'em-http-request'
require 'json'

EM.run {
  jsonified_body = {'aaaaa' => [10, 20], 'bbbbb' => [15, 25]}.to_json
  request = EM::HttpRequest.new('http://127.0.0.1:5150').post :body => jsonified_body
  request.callback { |http|
    puts http.response
  }
}
