require 'rcs-common/trace'
require 'rcs-common/winfirewall'

module RCS
  module DB
    module Firewall
      extend self
      extend RCS::Tracer

      RULE_PREFIX = "RCS_FWD"

      def developer_machine?
        Config.instance.global['SKIP_FIREWALL_CHECK']
      end

      def exists?
        WinFirewall.exists?
      end

      def disabled?
        exists? and (WinFirewall.status == :off)
      end

      def wait
        error_logged = false

        loop do
          break if developer_machine?
          break if !disabled?

          unless error_logged
            trace(:fatal, "Firewall is disabled. You must turn it on get this component work correcly.")
            error_logged = true
          end

          sleep(10)
        end
      end

      def create_default_rules(component=nil)
        return unless exists?

        # Do nothing in this case
        return if developer_machine? and disabled?

        if component == :worker
          rule_name = "#{RULE_PREFIX} Carrier to Worker"
          port = (Config.instance.global['LISTENING_PORT'] || 443) - 1
          trace(:info, "Creating firewall rule #{rule_name.inspect}")
          WinFirewall.del_rule(rule_name)
          WinFirewall.add_rule(action: :allow, direction: :in, name: rule_name, local_port: port, remote_ip: 'LocalSubnet', protocol: :tcp)
        end
      end
    end
  end
end
