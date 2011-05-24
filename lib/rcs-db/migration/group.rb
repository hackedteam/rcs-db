require 'rcs-db/db_layer'

module RCS
module DB

class GroupMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating groups "

    groups = DB.instance.mysql_query('SELECT * from `group` ORDER BY `group_id`;').to_a
    groups.each do |group|

      trace :info, "Migrating group '#{group[:group]}'." if verbose
      print "." unless verbose

      mg = ::Group.new
      mg[:_mid] = group[:group_id]
      mg.name = group[:group]
      mg.alert = group[:alert] == 0 ? false : true
      mg.save
    end

    puts " done."

  end

  def self.migrate_associations(verbose)

    print "Associating users to groups "

    associations = DB.instance.mysql_query('SELECT * from `group_user` ORDER BY `group_id`;').to_a
    associations.each do |a|
      group = Group.where({_mid: a[:group_id]}).first
      user = User.where({_mid: a[:user_id]}).first
      group.users << user

      trace :info, "Association user '#{user.name}' to group '#{group.name}'." if verbose
      print "." unless verbose
      
    end

    puts " done."
    
  end
end

end # ::DB
end # ::RCS
