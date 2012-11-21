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

    def translate(input_file, output_file)

      # take the address from the conf file
      sdl_server = RCS::DB::Config.instance.global['SDL_SERVER']
      sdl_url = "http://#{sdl_server}/lwserver-rest-5.3/v1/lang-pairs/_/sync-translations"

      #trace :debug, "REQUEST: #{File.read(input_file)}"

      # send the request to the SDL server
      response = RestClient.post sdl_url, {:target_lang_id => 'eng',
                                           :source_document => File.new(input_file, 'rb'),
                                           :multipart => true}
      # something went wrong
      return false if response.code != 200

      #trace :debug, "RESPONSE: #{response.body}"

      # fix the HTML tags
      fix_html_entities(content)

      # write the result to the output file
      File.open(output_file, 'w') {|f| f.write response.body}

      return true
    rescue Exception => e
      trace :error, "Error with SDL server: #{e.message} | #{e.backtrace.first}"
      return false
    end

    def fix_html_entities(content)
      # for some reason SDL output changes <html> to < html >
      # so we have to fix it by removing the spaces
      content.gsub!("< ", "<")
      content.gsub!(" >", ">")
    end

  end

end

end #DB::
end #RCS::
