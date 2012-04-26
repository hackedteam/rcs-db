require_relative 'single_evidence'

module RCS
module PasswordProcessing
  extend SingleEvidence

  def duplicate_criteria
    {"type" => :password,
     "data.program" => self[:data][:program],
     "data.service"=> self[:data][:service],
     "data.user"=> self[:data][:user],
     "data.pass"=> self[:data][:pass]}
  end

  def type
    :password
  end
end # PasswordProcessing
end # DB
