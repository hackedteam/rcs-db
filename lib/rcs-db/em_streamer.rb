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
      # @param [String] grid_io GridFS object
      #
      # @option args [Boolean] :http_chunks (false) Use HTTP 1.1 style chunked-encoding semantics.
      def initialize(connection, grid_io, args = {})
        @connection = connection
        stream_without_mapping grid_io
      end
      
      # @private
      def stream_without_mapping(grid_io)
        @grid_io = grid_io
        @size = @grid_io.file_length
        stream_one_chunk
      end
      private :stream_without_mapping
      
      # Used internally to stream one chunk at a time over multiple reactor ticks
      # @private
      def stream_one_chunk
        loop do
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
        end
      rescue Exception => e
        # catch all exceptions otherwise it will propagate up to the reactor and terminate the main program
      end
  end

  class FilesystemStreamer
    include EventMachine::Deferrable

      # Wait until next tick to send more data when 50k is still in the outgoing buffer
      BackpressureLevel = 50000
      # Send 16k chunks at a time
      ChunkSize = 16384

      # @param [EventMachine::Connection] connection
      # @param [String] filename Filesystem filename
      #
      # @option args [Boolean] :http_chunks (false) Use HTTP 1.1 style chunked-encoding semantics.
      def initialize(connection, filename, args = {})
        @connection = connection
        stream_without_mapping filename
      end

      # @private
      def stream_without_mapping(filename)
        if File.exist?(filename)
          @file_io = File.open(filename, "rb")
          @size = File.size(filename)
          stream_one_chunk
        else
          raise "FilesystemStreamer: File not found (#{filename})"
        end
      end
      private :stream_without_mapping

      # Used internally to stream one chunk at a time over multiple reactor ticks
      # @private
      def stream_one_chunk
        loop do
          if @connection.closed?
            @file_io.close unless @file_io.closed?
            break
          end
          if @file_io.pos < @size
            if @connection.get_outbound_data_size > BackpressureLevel
                # recursively call myself
                EventMachine::next_tick {stream_one_chunk}
                break
            else
              break unless @file_io.pos < @size

              len = @size - @file_io.pos
              len = ChunkSize if (len > ChunkSize)

              @connection.send_data(@file_io.read( len ))
            end
          else
            succeed
            @file_io.close
            break
          end
        end
      rescue Exception => e
        # catch all exceptions otherwise it will propagate up to the reactor and terminate the main program
        @file_io.close unless @file_io.closed?
      end
  end

end
