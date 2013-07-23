require_relative '../rest'
require_relative '../db_objects/signature'
require_relative '../db_objects/status'

module RCS
  module DB
    class SyncController < RESTController

      bypass_auth [:evidence, :operation, :status, :setup]

      def valid_signature?
        received = @request[:headers][:x_sync_signature]
        expected = Signature.where(scope: 'network').first.try(:value)
        !received.blank? and received == expected
      end

      def has_signatures?
        Signature.all.count > 0
      end

      def evidence
        return not_authorized(msg: 'Invalid signature') unless valid_signature?

        evidence_attributes = @params[:evidence]

        # TODO: store the evidence
        ok
      end

      def operation
        return not_authorized(msg: 'Invalid signature') unless valid_signature?

        evidence_attributes = @params[:items]

        # TODO: store all the operation items
        ok
      end

      def status
        return not_authorized(msg: 'Invalid signature') unless valid_signature?

        status = Status.where(type: 'db').first
        if status
          ok(status: status)
        else
          server_error(msg: 'Status not computed yet')
        end
      end

      def setup
        signatures = @params[:signatures]

        return bad_request(msg: 'Expected signatures') unless signatures

        if has_signatures?
          if valid_signature?
            ok(msg: 'Nothing was changed')
          else
            server_error(msg: 'Signature was alredy written and cannot be changed with a different one')
          end
        else
          # TODO: store signatures
          ok(msg: 'Signature stored')
        end
      end
    end
  end
end