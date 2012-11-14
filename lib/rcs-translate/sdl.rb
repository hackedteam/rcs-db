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

    # TODO: put it in the conf file
    SDL_SERVER = "172.16.42.17:8090"
    SDL_URL = "http://#{SDL_SERVER}/lwserver-rest-5.3/v1/lang-pairs/_/sync-translations"

    def translate(input_file, output_file)
      # send the request to the SDL server
      response = RestClient.post SDL_URL, {:target_lang_id => 'eng',
                                           :source_document => File.new(input_file, 'rb'),
                                           :multipart => true}
      # something went wrong
      return false if response.code != 200

      # write the result to the output file
      File.open(output_file, 'w') {|f| f.write response.body}

      return true
    rescue Exception => e
      trace :debug, "Error with SDL server: #{e.message}"
      return false
    end

  end

end

end #DB::
end #RCS::
