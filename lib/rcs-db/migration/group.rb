require 'rcs-db/db_layer'

module RCS
module DB

class GroupMigration
  extend Tracer
  
  def self.migrate
    groups = DB.instance.mysql_query('SELECT * from `group` ORDER BY `group_id`;').to_a
    groups.each do |group|
      trace :debug, "Migrating group '#{group[:group]}'."
      mg = ::Group.new
      mg[:_mid] = group[:group_id]
      mg.name = group[:group]
      mg.alert = group[:alert] == 0 ? false : true
      mg.save
      #trace :debug, mg.inspect
    end
  end

  def self.migrate_associations
    associations = DB.instance.mysql_query('SELECT * from `group_user` ORDER BY `group_id`;').to_a
    associations.each do |a|
      begin
        group = Group.where({_mid: a[:group_id]}).first
        user = User.where({_mid: a[:user_id]}).first
      rescue Exception => e
        trace :debug, "Group '#{a[:group_id]}' not found, skipping..."
        next
      end
      trace :debug, "Association user '#{user.name}' to group '#{group.name}'."
      group.users << user
    end
  end
end

end # ::DB
end # ::RCS
