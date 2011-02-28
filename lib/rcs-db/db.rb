#
# The main file of the DB
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class Application
  # To change this template use File | Settings | File Templates.
  def run(options)
    puts "DB up and running!"
    return 0
  end

 # we instantiate here an object and run it
  def self.run!(*argv)
    return Application.new.run(argv)
  end
end


end
end