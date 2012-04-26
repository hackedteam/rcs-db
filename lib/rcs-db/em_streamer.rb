require 'eventmachine'
require_relative 'grid'

module EventMachine
  class GridStreamer
    include EventMachine::Deferrable
      
      # Wait until next tick to send more data when 50k is still in the outgoing buffer
      BackpressureLevel = 50000
      # Send 16k chunks at a time
      ChunkSize = 16384
      
      # @param [EventMachine::Connection] connection
      # @param [String] filename File path
      #
      # @option args [Boolean] :http_chunks (false) Use HTTP 1.1 style chunked-encoding semantics.
      def initialize connection, grid_io, args = {}
        @connection = connection
        stream_without_mapping grid_io
      end
      
      # @private
      def stream_without_mapping grid_io
        @grid_io = grid_io
        @size = @grid_io.file_length
        stream_one_chunk
      end
      private :stream_without_mapping
      
      # Used internally to stream one chunk at a time over multiple reactor ticks
      # @private
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
            break
          end
        }
      end
  end
end
