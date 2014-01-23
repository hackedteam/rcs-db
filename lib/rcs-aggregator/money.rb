require 'rcs-common/trace'

module RCS
  module Aggregator
    class MoneyAggregator
      include RCS::Tracer
      extend RCS::Tracer

      def self.extract_tx(evidence)
        data = evidence.data

        return [] if data['type'] != :tx

        versus = data['incoming'] == 1 ? :in : :out
        from, rcpt = data['from'], data['rcpt']

        return [] unless from and rcpt

        extracted_data = {
          sender:     from,
          peer:       rcpt,
          versus:     versus,
          size:       data['amount'],
          type:       data['currency'],
          time:       evidence.da
        }

        # TODO - remove this line
        trace(:debug, "Extraced data from evidence TX is #{extracted_data.inspect}")

        [extracted_data]
      end
    end
  end
end
