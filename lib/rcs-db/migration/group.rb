require 'rcs-db/db_layer'

module RCS
module DB

class GroupMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating groups "

    groups = DB.instance.mysql_query('SELECT * from `group` ORDER BY `group_id`;').to_a
    groups.each do |group|

      # skip item if already migrated
      next if ::Group.count(conditions: {_mid: group[:group_id]}) != 0

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

      # skip already migrated associations
      next if group.user_ids.include? user[:_id]

      group.users << user

      trace :info, "Association user '#{user.name}' to group '#{group.name}'." if verbose
      print "." unless verbose
      
    end

    # purge the invalid associations
    Group.all.each do |group|
      group.user_ids.each do |user_id|
        if User.where({_id: user_id}).first.nil?
          group.user_ids.delete(user_id)
          group.save
        end
      end
    end

    puts " done."
    
  end
end

end # ::DB
end # ::RCS
