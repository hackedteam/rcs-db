#
#  SDL interface
#

# from RCS::Common
require 'rcs-common/trace'

require 'rest_client'

module RCS
module Translate

class SDL
  extend RCS::Tracer

  class << self

    SDL_SERVER = "1.1.1.1"
    SDL_URL = "http://#{SDL_SERVER}/v1/lang-pairs/_/sync-translations"

    def translate(input_file, output_file)

      RestClient.log = Logger.new(STDOUT)

      # send the request to the SDL server
      response = RestClient.post SDL_URL, {:target_lang_id => 'eng',
                                           :source_document => File.new(input_file, 'rb'),
                                           :multipart => true}

      trace :debug, response.inspect

      return false if response.code != 200

      File.open(output_file, 'w') {|f| f.write response.body}

      return true
    end

  end

end

end #DB::
end #RCS::
