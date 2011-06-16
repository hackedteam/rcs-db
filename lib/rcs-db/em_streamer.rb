require 'eventmachine'
require 'evma_httpserver'

require 'forwardable'

require 'rcs-common/mime'

module EventMachine
  
	class DelegatedHttpFileResponse < HttpResponse
		
		ChunkSize = 16384
		
		extend Forwardable
		def_delegators :@connection,
			:send_data,
			:close_connection,
			:close_connection_after_writing
    
		def initialize connection, filename
			super()
			@filename = filename
			@size = File.size @filename
			@connection = connection
		end
		
		def fixup_headers
	    @headers["Content-length"] = File.size @filename
	    
	    # TODO: remove RCS dependency 
	    @headers["Content-Type"] = RCS::MimeType.get @filename
	    http_headers = @connection.instance_variable_get :@http_headers
	    if http_headers.split("\x00").index {|h| h['Connection: keep-alive'] || h['Connection: Keep-Alive']} then
            # keep the connection open to allow multiple requests on the same connection
            # this will increase the speed of sync since it decrease the latency on the net
            keep_connection_open true
            @headers['Connection'] = 'keep-alive'
          else
            @headers['Connection'] = 'close'
      end
	  end
		
		def send_body
		  stream_with_mapping @filename
	  end
	  
	  def stream_with_mapping filename # :nodoc:
      @position = 0
      @mapping = EventMachine::FastFileReader::Mapper.new @filename
      stream_one_chunk
    end
    
    def stream_one_chunk
      loop {
          if @position < @size
            len = @size - @position
            len = ChunkSize if (len > ChunkSize)
            
            @connection.send_data( @mapping.get_chunk( @position, len ))
            
            @position += len
          else
            @mapping.close
            break
          end
        }
      end
    
	end # DelegatedHttpFileResponse
	
	class DelegatedHttpGridResponse < HttpResponse
	  
	  ChunkSize = 16384
	  
	  extend Forwardable
		def_delegators :@connection,
			:send_data,
			:close_connection,
			:close_connection_after_writing
    
		def initialize connection, grid_io
			super()
			@grid_io = grid_io
			@connection = connection
		end
		
		def fixup_headers
		  puts @grid_io.content_type
	    @headers["Content-length"] = @grid_io.file_length
	    
	    @headers["Content-Type"] = 'binary/octet-stream'
	    @headers["Content-Type"] = @grid_io.content_type unless @grid_io.content_type == ''
	    
	    http_headers = @connection.instance_variable_get :@http_headers
	    if http_headers.split("\x00").index {|h| h['Connection: keep-alive'] || h['Connection: Keep-Alive']} then
            # keep the connection open to allow multiple requests on the same connection
            # this will increase the speed of sync since it decrease the latency on the net
            keep_connection_open true
            @headers['Connection'] = 'keep-alive'
          else
            @headers['Connection'] = 'close'
      end
	  end
		
		def send_body
		  stream_with_mapping @filename
	  end
	  
	  def stream_with_mapping filename # :nodoc:
      stream_one_chunk
    end
    
    def stream_one_chunk
      loop {
          break unless @grid_io.file_position < @grid_io.file_length
          
          len = @grid_io.file_length - @grid_io.file_position
          len = ChunkSize if (len > ChunkSize)
          
          @connection.send_data( @grid_io.read( len ))
        }
      end
    
	end # DelegatedHttpGridResponse

end # ::EventMachine
