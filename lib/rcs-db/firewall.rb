require 'rcs-common/trace'
require 'rcs-common/winfirewall'

module RCS
  module DB
    module Firewall
      extend self
      extend RCS::Tracer

      RULE_PREFIX = "RCS_FWD"

      def ok?
        !error_message
      end

      def error_message
        return nil if !WinFirewall.exists?
        return nil if developer_machine?
        return "Firewall must be activated on all profiles" if WinFirewall.status == :off
        return "Firewall default policy must block incoming connections by default" if !WinFirewall.block_inbound?
        nil
      end

      # Wait until the firewall is healty (#error_message returns nil)
      def wait
        last_err = nil

        loop do
          err = Firewall.error_message

          trace(:info, "Firewall is now ok.") if !err and last_err

          break if !err

          if err and err != last_err
            trace(:fatal, "#{err}. You must fix this on get this component work correcly.")
            last_err = err
          end

          sleep(10)
        end
      end

      def create_default_rules(component=nil)
        return if !WinFirewall.exists?

        if component == :worker
          rule_name = "#{RULE_PREFIX} Carrier to Worker"
          port = (Config.instance.global['LISTENING_PORT'] || 443) - 1
          trace(:info, "Creating firewall rule #{rule_name.inspect}")
          WinFirewall.del_rule(rule_name)
          WinFirewall.add_rule(action: :allow, direction: :in, name: rule_name, local_port: port, remote_ip: 'LocalSubnet', protocol: :tcp)
        elsif component == :db
          # DB related rules are created by the nsis installer
        end
      end

      private

      def developer_machine?
        Config.instance.global['SKIP_FIREWALL_CHECK']
      end
    end
  end
end
