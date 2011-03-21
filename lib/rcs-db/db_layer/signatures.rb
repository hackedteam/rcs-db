#
# Mix-in for DB Layer
#

module Signatures

  def signature(sign)

    mysql_query("SELECT sign FROM sign WHERE scope = '#{sign}'").each do |row|
      return row
    end

  end

end