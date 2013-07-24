require 'thread'
require 'rest-client'
require 'rcs-common/trace'
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
        Status.where(address: address, type: 'archive').first
      end

      def request_setup
        body = {signatures: Signature.all.to_json}
        request("sync/setup", body)
      end

      def request_status
        request("sync/status") { |content| update_status(content[:status]) }
      end

      def request(path, body = {})
        url = "https://#{address}/#{path}"
        trace :debug, "ArchiveNode #{address}, POST #{path} with #{body.inspect}"
        headers = {x_sync_signature: signature}
        RestClient::Request.execute(:method => :post, :url => url, :payload => body.to_json, :headers => headers, :timeout => 3, :open_timeout => 3) do |resp|
          trace :debug, "ArchiveNode #{address}, POST RESPONSE: #{resp.code}, #{resp.body}"
          content = JSON.parse(resp.body).symbolize_keys rescue {}
          if resp.code != 200
            set_error_status(content[:msg] || "Got error #{code} from archive node")
          elsif block_given?
            yield(content)
          end
        end
      rescue RestClient::RequestTimeout => error
        trace :debug, "ArchiveNode #{address}, POST timed out"
        set_error_status("Unable to reach #{address}. Request timeout.")
      end

      def set_error_status(message)
        update_status(status: Status::ERROR, info: message)
      end

      def update_status(attributes)
        current = status.try(:attributes) || {}
        attributes = current.symbolize_keys.merge(attributes.symbolize_keys)
        stats = attributes.reject { |key| ![:disk, :cpu, :pcpu].include?(key) }
        status_code = Status::STATUS_CODE.find { |key, val| val == attributes[:status] }.try(:first) || attributes[:status]
        params = ["RCS::DB (Archive)", address, status_code, attributes[:info], stats, 'archive', attributes[:version]]

        Status.status_update(*params)
      end

      def destroy
        status.destroy if status
      end

      def self.all
        addresses = Connector.where(type: 'archive').only('dest').distinct('dest')
        addresses.map! { |addr| new(addr) }
      end

      def self.ping_all
        trace :info, 'update all statuses...'
        all.each { |archive_node| archive_node.request_status }
      end
    end
  end
end
