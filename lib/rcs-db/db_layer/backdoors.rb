#
# Mix-in for DB Layer
#

module DBLayer

module Backdoors

  def backdoor_evidence_key(bid)
    mysql_escape bid
    key = mysql_query("SELECT logkey FROM backdoor WHERE backdoor_id = #{bid}").to_a
    return key[0][:logkey]
  end

  def backdoor_class_keys
    mysql_query("SELECT build, confkey FROM backdoor WHERE class = 1").to_a
  end

  def backdoor_class_key(build)
    mysql_escape build
    mysql_query("SELECT build, confkey FROM backdoor WHERE class = 1 AND build = '#{build}'").to_a
  end

  def backdoor_status(build, instance, subtype)
    mysql_escape build, instance, subtype
    mysql_query("SELECT backdoor_id, status, deleted
                 FROM backdoor
                 WHERE build = '#{build}ss'
                       AND instance = '#{instance}'
                       AND subtype = '#{subtype}'").to_a.first
  end

  def backdoor_config(bid)
    mysql_escape bid
    #TODO: implement config creation
    return nil
  end

  def backdoor_config_sent(bid)
    mysql_escape bid
    mysql_query("UPDATE config SET sent = UTC_TIMESTAMP() WHERE backdoor_id = #{bid} AND sent IS '0000-00-00 00:00:00'")
  end

  def backdoor_uploads(bid)
    mysql_escape bid
    mysql_query("SELECT upload_id, filename FROM upload WHERE backdoor_id = #{bid}").to_a
  end

  def backdoor_upload(bid, id)
    mysql_escape bid, id
    mysql_query("SELECT content FROM upload WHERE backdoor_id = #{bid} AND upload_id = #{id}").to_a.first
  end

  def backdoor_del_upload(bid, id)
    mysql_escape bid, id
    mysql_query("DELETE FROM upload WHERE backdoor_id = #{bid} AND upload_id = #{id}")
  end

  def backdoor_upgrades(bid)
    mysql_escape bid
    mysql_query("SELECT upgrade_id, filename FROM upgrade WHERE backdoor_id = #{bid}").to_a
  end

  def backdoor_upgrade(bid, id)
    mysql_escape bid, id
    mysql_query("SELECT content FROM upgrade WHERE backdoor_id = #{bid} AND upgrade_id = #{id}").to_a.first
  end

  def backdoor_del_upgrades(bid)
    mysql_escape bid
    mysql_query("DELETE FROM upgrade WHERE backdoor_id = #{bid}")
  end

  def backdoor_downloads(bid)
    mysql_escape bid
    mysql_query("SELECT download_id, filename FROM download WHERE backdoor_id = #{bid}").to_a
  end

  def backdoor_del_download(bid, id)
    mysql_escape bid, id
    mysql_query("DELETE FROM download WHERE backdoor_id = #{bid} AND download_id = #{id}")
  end

  def backdoor_filesystems(bid)
    mysql_escape bid
    mysql_query("SELECT filesystem_id, path, depth FROM filesystem WHERE backdoor_id = #{bid}").to_a
  end

  def backdoor_del_filesystem(bid, id)
    mysql_escape bid, id
    mysql_query("DELETE FROM filesystem WHERE backdoor_id = #{bid} AND filesystem_id = #{id}")
  end

end # ::Backdoors
end # ::DBLayer