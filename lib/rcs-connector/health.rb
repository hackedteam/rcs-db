module RCS
  module Connector
    class Health
      attr_accessor :desc
      attr_accessor :kind

      FAR_AWAY = 1.hour

      def initialize
        self.desc = "Idle"
        self.kind = :healthy
      end

      def change_to(kind, desc)
        @last_error_at = Time.now if kind == :sick
        self.kind = kind
        self.desc = desc
      end

      def still_sick?
        return false unless @last_error_at
        Time.now - @last_error_at < FAR_AWAY
      end
    end
  end
end
