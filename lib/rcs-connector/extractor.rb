module RCS
  module Connector
    class Extractor
      include RCS::Tracer

      attr_reader :evidence, :format

      def initialize(evidence, destination, format)
        @evidence = evidence
        @destination = destination
        @format = format
      end

      def agent
        @agent ||= ::Item.find(evidence.aid)
      end

      def operation
        @operation ||= ::Item.find(agent.path.first)
      end

      def target
        @target ||= ::Item.find(agent.path.last)
      end

      def destination
        folders = [@destination]
        folders << "#{operation.name}-#{operation.id}"
        folders << "#{target.name}-#{target.id}"
        folders << "#{agent.name}-#{agent.id}"
        File.join(*folders).tap { |p| FileUtils.mkdir_p(p) }
      end

      def evidence_content
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

        format == 'XML' ? exported.to_xml(root: 'evidence') : exported.to_json
      end

      def grid_content
        file = RCS::DB::GridFS.get(evidence.data['_grid'], target.id.to_s)
        file.read
      end

      def dump
        ext = format.to_s.downcase
        path = File.join(destination, "#{evidence.id}.#{ext}")

        # dump the evidence
        File.open(path, 'wb') { |d| d.write(evidence_content) }

        # dump the binary (if any)
        if evidence.data['_grid']
          path = File.join(destination, "#{evidence.id}.bin")
          File.open(path, 'wb') { |d| d.write(grid_content) }
        end
      end
    end
  end
end
