module RCS
  module Connector
    class DispatcherStatus
      attr_accessor :desc
      attr_accessor :kind

      FAR_AWAY = 1.hour

      def initialize
        self.desc = "Idle"
        self.kind = :healthy
      end

      def change_to(kind, desc)
        return if kind == :healthy and !last_error_is_far_away?
        @last_error_at = Time.now if kind == :sick
        self.kind = kind
        self.desc = desc
      end

      def last_error_is_far_away?
        return true unless @last_error_at
        Time.now - @last_error_at > FAR_AWAY
      end
    end
  end
end
