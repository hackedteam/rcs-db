#
# Layer for accessing the real DB
#

# include all the mix-ins
Dir[File.dirname(__FILE__) + '/db_layer/*.rb'].each do |file|
  require file
end

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/flatsingleton'

module RCS
module DB

class DB
  include Singleton
  extend FlatSingleton
  include RCS::Tracer

  def initialize
    
  end

  # in the mix-ins there are all the methods for the respective section
  include Users
  include Backdoors
  include Status


end

end #DB::
end #RCS::
