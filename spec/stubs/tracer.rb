module RCS
  module Stubs

    # Helper to create an instance of Logger only if options
    # are changed since the last time the class was created.
    def self.logger(opts = {})
      @logger = nil if @logger and @logger.opts != opts
      @logger ||= Logger.new(opts)
    end

    # Stub Log4r::Logger class. Used in the tracer
    # module of rcs-common gem.
    class Logger
      attr_reader :opts

      def initialize(opts = {})
        @opts = {print_errors: true, raise_errors: true}.merge(opts)
      end

      def method_missing(*args); end

      # Prevent calling Kernel#warn with send
      def warn(*args); end

      def raise_error(msg)
        return unless opts[:raise_errors]
        raise msg
      end

      def yellow(text); "\033[30;33m#{text}\033[0m"; end

      def print_error(ex)
        return unless opts[:print_errors]
        file_and_line = caller.find {|line| line =~ /_spec.rb/ }.scan(/\/([^\/]+)\:in\s/).flatten.first rescue nil
        file_and_line = " (#{file_and_line})" if file_and_line
        message = ex.respond_to?(:message) && ex.message || ex
        puts yellow("trace error#{file_and_line}: " + message[0, 100].gsub("\n", '/') + "#{'...' if message.size >= 100}")
      end

      alias_method :error, :print_error
      alias_method :fatal, :raise_error
    end
  end
end
