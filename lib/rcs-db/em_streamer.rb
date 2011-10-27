require 'eventmachine'
require 'evma_httpserver'
require 'fastfilereaderext'

require 'forwardable'

require 'rcs-common/mime'

module EventMachine
  
	class DelegatedHttpFileResponse < HttpResponse
    include EventMachine::Deferrable
		
		ChunkSize = 16384
    BackpressureLevel = 50000
		
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
	    @headers["Content-length"] = @size
	    
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
        break if @connection.closed?
        if @position < @size
          if @connection.get_outbound_data_size > BackpressureLevel
            EventMachine::next_tick {stream_one_chunk}
            break
          else
            break unless @position < @size
            len = @size - @position
            len = ChunkSize if (len > ChunkSize)

            @connection.send_data( @mapping.get_chunk( @position, len ))

            @position += len
          end
        else
          @mapping.close
          succeed
          #puts "streamed #{@position} bytes."
          break
        end
      }
    end
    
	end # DelegatedHttpFileResponse
	
	class DelegatedHttpGridResponse < HttpResponse
    include EventMachine::Deferrable
	  
	  ChunkSize = 16384
    BackpressureLevel = 50000
	  
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
      
	    @headers["Content-length"] = @grid_io.file_length
	    @headers["Content-Type"] = @grid_io.content_type
      @headers["Content-Type"] ||= 'binary/octet-stream'
	    
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
		  stream_with_mapping
	  end
	  
	  def stream_with_mapping filename # :nodoc:
      @size = @grid_io.file_length
      stream_one_chunk
    end
    
    def stream_one_chunk
      loop {
        break if @connection.closed?
        if @grid_io.file_position < @grid_io.file_length
          if @connection.get_outbound_data_size > BackpressureLevel
              EventMachine::next_tick {stream_one_chunk}
              break
          else
            break unless @grid_io.file_position < @grid_io.file_length
            
            len = @grid_io.file_length - @grid_io.file_position
            len = ChunkSize if (len > ChunkSize)
            
            @connection.send_data( @grid_io.read( len ))
          end
        else
          succeed
          #puts "streamed #{@position} bytes."
          break
        end
      }
    end
    
	end # DelegatedHttpGridResponse

end # ::EventMachine
