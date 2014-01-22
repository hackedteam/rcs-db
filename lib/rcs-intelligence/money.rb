require 'rcs-common/trace'
# require_release 'rcs-db/link_manager'

module RCS
  module Intelligence
    module Money
      extend self
      extend RCS::Tracer

      def self.valid_tx_evidence?(evidence)
        data = evidence.data
        return false if data['type'] != :tx

        %w[from rcpt currency].each do |attr_name|
          return false unless data[attr_name]
        end

        true
      end

      def self.process_tx(entity, evidence)
        return unless valid_tx_evidence?(evidence)

        data = evidence.data

        from, rcpt, currency = data['from'], data['rcpt'], data['currency']

        from, rcpt = rcpt, from if data['incoming'] == 1

        # Ensure that the current entity has an handle that match
        # the tx input address
        # TODO (or create the handle?)
        if entity.handles.where(type: currency, handle: from).empty?
          trace(:error, "Entity #{entity.name} does not own the #{currency} address #{from}")
          return
        end

        # Search other entities to find an handle that match
        # the tx output address
        Entity.with_handle(data['currency'], rcpt, exclude: entity).each { |rcpt_entity|
          amount = data['amount']
          trace(:info, "Entity #{entity.name} sent #{amount} #{currency}(s) to #{rcpt_entity.name}")
          RCS::DB::LinkManager.instance.add_link(from: entity, to: rcpt_entity, level: :automatic, type: :peer, versus: :out, info: "#{from} #{rcpt}")
        }

        # TODO: search the handlebook
      end
    end
  end
end
