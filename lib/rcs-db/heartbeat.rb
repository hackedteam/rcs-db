# encoding: utf-8

require 'rcs-common/heartbeat'

require_relative 'db_layer'
require_relative 'license'
require_relative 'shard'

module RCS::DB
  class HeartBeat < RCS::HeartBeat::Base
    component 'db', 'RCS::DB'

    before_heartbeat do
      # check the consistency of the license
      LicenseManager.instance.periodic_check

      # check if someone has tampered with the license.rb file
      self.class.dont_steal_rcs

      # check the status of the DB shards
      check_shards
    end

    def self.dont_steal_rcs
      if LicenseManager::DONT_STEAL_RCS != "Ò€‹›ﬁﬂ‡°·‚æ…¬˚∆˙©ƒ∂ß´®†¨ˆøΩ≈ç√∫˜µ≤¡™£¢∞§¶•ªº" or
        RCS::DB::Dongle::DONT_STEAL_RCS != "∆©ƒø†£¢∂øª˚¶∞¨˚˚˙†´ßµ∫√Ïﬁˆ¨Øˆ·‰ﬁÎ¨"
        trace :fatal, "TAMPERED SOURCE CODE: don't steal RCS, now you are in trouble..."
        exit!
      end
    end

    def check_shards
      shards = Shard.all
      shards['shards'].each do |shard|
        status = Shard.find(shard['_id'])

        next if status['ok'] != 0

        trace :fatal, "Heartbeat shard check: #{status['errmsg']}"

        RCS::SystemStatus.my_status = 'ERROR'
        RCS::SystemStatus.my_error_msg = status['errmsg']
      end
    rescue Exception => e
      trace :fatal, "Cannot perform shard check: #{e.message}"
    end

    def message
      "#{SessionManager.instance.all.size} connections..."
    end
  end
end
