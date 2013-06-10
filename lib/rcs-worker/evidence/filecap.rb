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
    # use the info of the file to create an entry in the filesystem structure
    agent = get_agent
    target = agent.get_parent

    # don't add duplicates
    return unless ::Evidence.collection_class(target[:_id]).where(
        {:aid => agent[:_id].to_s,
         :type => 'filesystem',
         'data.path' => self[:data][:path]}).empty?

    ::Evidence.collection_class(target[:_id]).create do |ev|
      ev.aid = agent[:_id].to_s
      ev.type = 'filesystem'

      ev.da = self[:da].to_i
      ev.dr = self[:dr].to_i
      ev.rel = 0
      ev.blo = false
      ev.note = ""

      data = {}
      data[:path] = self[:data][:path]
      data[:attr] = 0 # is a file
      data[:size] = self[:data][:size]

      ev.data = data
    end
  end

end # ApplicationProcessing
end # DB
