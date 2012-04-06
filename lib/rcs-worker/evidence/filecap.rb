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
end # ApplicationProcessing
end # DB
