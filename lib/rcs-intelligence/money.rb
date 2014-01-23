require 'rcs-common/trace'
require 'rcs-common/evidence/money'
# require_release 'rcs-db/link_manager'

module RCS
  module Intelligence
    class MoneyTxProcessor
      include RCS::Tracer

      attr_reader :sender, :receiver, :currency, :versus

      def initialize(entity, aggregate)
        @entity = entity
        data = aggregate.data

        @sender   = data['sender']
        @receiver = data['peer']
        @incoming = data['versus'] == :in
        @versus   = data['versus']
        @currency = aggregate.type
      end

      def outgoing?
        !incoming?
      end

      def incoming?
        @incoming
      end

      # The address of the current #entity
      def entity_address
        @entity_address ||= incoming? ? receiver : sender
      end

      # Note: In case of incoming tx the sender address is nil (while the rcpt addr
      # is owned by #entity). In case of outgoing tx both addr are not-nil.
      def other_address
        @other_address ||= incoming? ? sender : receiver
      end

      # Ensure that #entity has an handle that match #entity_address
      # otherwise create it
      def ensure_entity_address!
        handle = @entity.handles.where(type: currency, handle: entity_address).first
        return handle if handle

        trace(:info, "Entity #{@entity.name} does not own the #{currency} address #{entity_address}, adding handle...")
        @entity.create_or_update_handle(currency, entity_address, entity_address)
      end

      def process
        return unless other_address

        ensure_entity_address!

        # Search other entities to find an handle that match #other_address
        Entity.with_handle(currency, other_address, exclude: @entity).each { |other_entity|
          trace(:info, "Entity #{@entity.name} #{incoming? ? 'received' : 'sent'} some #{currency}s #{incoming? ? 'from' : 'to'} #{other_entity.name}")
          info = outgoing? ? "#{entity_address} #{other_address}" : "#{other_address} #{entity_address}"
          RCS::DB::LinkManager.instance.add_link(from: @entity, to: other_entity, level: :automatic, type: :peer, versus: versus, info: info)
        }
      end
    end


    module Money
      extend self

      def known_cryptocurrencies
        RCS::MoneyEvidence::TYPES.keys
      end

      def process_money_tx_aggregate(entity, aggregate)
        MoneyTxProcessor.new(entity, aggregate).process
      end
    end
  end
end
