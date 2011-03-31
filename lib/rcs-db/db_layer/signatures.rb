#
# Mix-in for DB Layer
#

module DBLayer
module Signatures

  def signature(sign)

    mysql_query("SELECT sign FROM sign WHERE scope = '#{sign}'").each do |row|
      return row
    end

  end

end # ::Signatures
end # ::DBLayer