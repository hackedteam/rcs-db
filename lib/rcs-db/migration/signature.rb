require_relative '../db_layer'

module RCS
module DB

class SignatureMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating signatures "

    # make sure there are no conflicts
    ::Signature.delete_all

    signs = DB.instance.mysql_query('SELECT * from `sign`;').to_a
    signs.each do |sign|

      # skip item if already migrated
      next if Signature.count(conditions: {scope: sign[:scope]}) != 0

      sign[:scope] = 'agent' if sign[:scope] == 'backdoor'

      trace :info, "Migrating signature '#{sign[:scope]}'." if verbose
      print "." unless verbose
      
      ms = ::Signature.new
      ms.scope = sign[:scope]
      ms.value = sign[:sign]
      
      ms.save
    end
    
    puts " done."
    
  end
end

end # ::DB
end # ::RCS
