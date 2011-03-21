#
# Mix-in for DB Layer
#

module Backdoors

  def backdoor_evidence_key(bid)
    #TODO: implement the evidence key
    return 'magical-key'
  end

  def backdoor_class_keys
    mysql_query("SELECT build, confkey FROM backdoor WHERE class = 1").to_a
  end

  def backdoor_class_key(build)
    mysql_query("SELECT build, confkey FROM backdoor WHERE class = 1 AND build = '#{build}'").to_a
  end

end