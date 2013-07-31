module RCS
  module Connector
    class Pool
      include RCS::Tracer

      def initialize(global_health)
        @running = []
        @mutex = Mutex.new
        @global_health = global_health
      end

      def empty?
        synchronize { @running.empty? }
      end

      def has_thread?(name)
        synchronize { @running.include?(name) }
      end

      def defer(name)
        synchronize { @running << name }

        trace :debug, "Starting thread '#{name}'"

        Thread.new do
          begin
            Thread.current[:name] = name
            Thread.current.abort_on_exception = true
            yield
          rescue Exception => ex
            trace(:error, "#{ex.message}, backtrace: #{ex.backtrace}")
            synchronize { @global_health.change_to(:sick, "Some errors occurred. Check the logfile.") }
          ensure
            synchronize do
              @running.delete(name)
              trace :debug, "Ended. Killing myself. #{@running.size} dispatcher threads still running."
              Thread.current.kill
            end
          end
        end
      end

      def synchronize(&block)
        @mutex.synchronize(&block)
      end
    end
  end
end
