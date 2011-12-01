require_relative '../db_layer'

module RCS
module DB

class UserMigration
  extend Tracer
  
  def self.migrate(verbose = false)

    print "Migrating users "

    users = DB.instance.mysql_query('SELECT * from `user` ORDER BY `user_id`;').to_a
    users.each do |user|

      # skip item if already migrated
      next if ::User.count(conditions: {_mid: user[:user_id]}) != 0

      # if the same user is imported multiple times, update the _mid and go on
      #       (for multiple server migration)
      u = ::User.where(name: user[:user]).first
      unless u.nil?
        u._mid = user[:user_id]
        u.save
        next
      end

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
      mu.dashboard_ids = []
      mu.recent_ids = []
      mu.privs = []

      if user[:level] & 0x80 != 0
        mu.privs << 'ADMIN'
        mu.privs << 'SYS'
      end
      mu.privs << 'TECH' if user[:level] & 0x02 != 0
      mu.privs << 'VIEW' if user[:level] & 0x01 != 0
      mu.save
      #trace :debug, mu.inspect
    end

    puts " done."

  end
end

end # ::DB
end # ::RCS