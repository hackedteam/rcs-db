require 'rcs-db/db_layer'

module RCS
module DB

class UserMigration
  extend Tracer
  
  def self.migrate(verbose = false)

    print "Migrating users " unless verbose

    users = DB.instance.mysql_query('SELECT * from `user` ORDER BY `user_id`;').to_a
    users.each do |user|
      
      trace :info, "Migrating user '#{user[:user]}'." if verbose
      print "." unless verbose

      mu = ::User.new
      mu[:_mid] = user[:user_id]
      mu.name = user[:user]
      mu.desc = user[:desc]
      mu.pass = user[:pass]
      mu.contact = user[:contact]
      mu.locale = 'en_US'
      mu.timezone = 0
      mu.enabled = user[:disabled] == 0 ? true : false
      mu.privs = []
      mu.privs << 'ADMIN' if user[:level] & 0x80
      mu.privs << 'TECH' if user[:level] & 0x02
      mu.privs << 'VIEW' if user[:level] & 0x01
      mu.save
      #trace :debug, mu.inspect
    end

    puts " done." unless verbose

  end
end

end # ::DB
end # ::RCS